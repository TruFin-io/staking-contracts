import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { smock } from '@defi-wonderland/smock';
import { AddressZero } from "@ethersproject/constants";
import * as helpers from "@nomicfoundation/hardhat-network-helpers";
import * as constants from "../helpers/constants";

const chainId = 1;

const parseEther = ethers.utils.parseEther;
const formatEther = ethers.utils.formatEther;
const toBN = ethers.BigNumber.from;
const ZERO_ADDRESS = ethers.constants.AddressZero;
const provider = ethers.provider;

// needed because solidity div always rounds down
const expectDivEqual = (a: any, b: any) => expect(a - b).to.be.oneOf([0, 1]);

const getAddressMappingStorageIndex = (address, mappingIndex) =>
    ethers.utils.solidityKeccak256(["uint256", "uint256"], [address, mappingIndex]);

const getBalanceStorageIndex = (address: String) => getAddressMappingStorageIndex(address, 0);

const setTokenBalancesAndApprove = async (token, users, recipient, amount) => {
    const index = getBalanceStorageIndex(users[0].address);
    const callBalance = await token.balanceOf(users[0].address);
    const storageBalance = ethers.BigNumber.from(await helpers.getStorageAt(token.address, index));
    expect(storageBalance).to.equal(callBalance);

    for (let user of users) {
        // get balance storage index
        const userIndex = getBalanceStorageIndex(user.address);

        // set balance to amount
        await helpers.setStorageAt(token.address, userIndex, amount);

        // approve amount to recipient
        await token.connect(user).approve(recipient, amount);
    }
};

describe("Staker", () => {
    let deployer, treasury, user1, user2;
    let token, validatorShare, stakeManager, whitelist, staker;
    let snapshot: any;

    before(async () => {
        // load deployed contracts
        token = await ethers.getContractAt(
            constants.STAKING_TOKEN_ABI,
            constants.STAKING_TOKEN_ADDRESS[chainId],
        );
        validatorShare = await ethers.getContractAt(
            constants.VALIDATOR_SHARE_ABI,
            constants.VALIDATOR_SHARE_CONTRACT_ADDRESS[chainId],
        );
        stakeManager = await ethers.getContractAt(
            constants.STAKE_MANAGER_ABI,
            constants.STAKE_MANAGER_CONTRACT_ADDRESS[chainId]
        );

        // load signers, balances set to 10k ETH in hardhat config file
        [deployer, treasury, user1, user2] = await ethers.getSigners();

        // mock whitelist
        whitelist = await smock.fake(constants.WHITELIST_ABI);

        // add users to whitelist
        whitelist.isUserWhitelisted.returns((params : [string]) => {
          return [deployer, treasury, user1, user2].map(it => it.address).includes(params[0])
        });

        staker = await ethers
            .getContractFactory("TruStakeMATICv2")
            .then((stakerFactory) =>
                upgrades.deployProxy(stakerFactory, [
                    token.address,
                    stakeManager.address,
                    validatorShare.address,
                    whitelist.address,
                    treasury.address,
                    constants.PHI,
                    constants.DIST_PHI,
                ])
            );

        // make it the default validator
        await staker.setDefaultValidator(validatorShare.address);

        // set each balance to 10k MATIC and approve it to staker
        await setTokenBalancesAndApprove(
            token,
            [user1, user2, deployer],
            staker.address,
            parseEther("1000000")
        );

        // save snapshot
        snapshot = await helpers.takeSnapshot();
    });

    beforeEach(async () => {
        // reset to snapshot
        await snapshot.restore();
    });

    describe(`Scenario 1: transfer of allocated shares`, async () => {

        it(`Scenario`, async () => {
            // stake as user1 and user2
            const amount = parseEther("1000");
            await staker.connect(user1).deposit(amount);
            await staker.connect(user2).deposit(amount);

            // allocate
            await staker.connect(user1).allocate(parseEther("100"), user2.address);
            await staker.connect(user1).allocate(parseEther("400"), user2.address);

            await helpers.time.increase(10000000);
            await token.connect(user1).transfer(staker.address, parseEther("10"));

            await staker.connect(user1).transfer(deployer.address, (await staker.balanceOf(user1.address)).sub(parseEther("2.5")));

            const user2SharesBalanceBefore = await staker.balanceOf(user2.address);

            await staker.connect(user1).distributeRewards(user2.address, false);

            const user2SharesBalanceAfter = await staker.balanceOf(user2.address);


            expect(user2SharesBalanceAfter).to.be.gt(user2SharesBalanceBefore);
        });
    });
});
