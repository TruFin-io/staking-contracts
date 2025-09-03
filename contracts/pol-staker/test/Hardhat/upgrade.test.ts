import { impersonateAccount, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, upgrades } from "hardhat";

import * as constants from "../helpers/constants";

describe("Upgrade", () => {
  let staker, proxyAdminOwner;

  beforeEach(async () => {
    ({ staker, proxyAdminOwner } = await loadFixture(forkAtBlock));
  });

  it("can upgrade staker contract", async () => {
    const stakerFactory = await ethers.getContractFactory("TruStakePOL");
    const stakerAddress = constants.STAKER_ADDRESS[constants.CHAIN_ID.SEPOLIA];

    // Validates and deploys a new implementation contract and returns its address.
    const address = await upgrades.prepareUpgrade(stakerAddress, stakerFactory, {
      unsafeAllowRenames: true,
      kind: "transparent",
    });

    expect(address).to.be.lengthOf(42);
  });

  it("can access all storage variables after an upgrade", async () => {
    // Query storage variables in the Sepolia staker contract
    const {
      stakingTokenAddress,
      stakeManagerContractAddress,
      treasuryAddress,
      defaultValidatorAddress,
      whitelistAddress,
      delegateRegistry,
      epsilon,
      fee,
      minDeposit,
    } = await staker.stakerInfo();

    // Upgrade Staker contract
    const upgradedStaker = await upgradeStakerContract(proxyAdminOwner);

    // Verify that can access the same storage variables values
    const stakerInfo = await upgradedStaker.stakerInfo();
    expect(await stakerInfo.stakingTokenAddress).is.equal(stakingTokenAddress);
    expect(await stakerInfo.stakeManagerContractAddress).is.equal(stakeManagerContractAddress);
    expect(await stakerInfo.treasuryAddress).is.equal(treasuryAddress);
    expect(await stakerInfo.defaultValidatorAddress).is.equal(defaultValidatorAddress);
    expect(await stakerInfo.whitelistAddress).is.equal(whitelistAddress);
    expect(await stakerInfo.delegateRegistry).is.equal(delegateRegistry);
    expect(await stakerInfo.epsilon).is.equal(epsilon);
    expect(await stakerInfo.fee).is.equal(fee);
    expect(await stakerInfo.minDeposit).is.equal(minDeposit);
  });
});

const forkAtBlock = async () => {
  const forkBlock = 9116787;
  const proxyAdminOwner = "0xbb447Ff57D2Be03F6804aEB1A7d1ca06c01eD0C3";
  const [deployer] = await ethers.getSigners();

  await ethers.provider.send("hardhat_reset", [
    {
      forking: {
        jsonRpcUrl: process.env.SEPOLIA_RPC,
        blockNumber: forkBlock,
      },
    },
  ]);

  const staker = await ethers.getContractAt(
    constants.SEPOLIA_POL_STAKER_ABI,
    constants.STAKER_ADDRESS[constants.CHAIN_ID.SEPOLIA],
  );

  // transfer some ETH to the proxy admin owner
  await deployer.sendTransaction({
    to: proxyAdminOwner,
    value: ethers.parseEther("5"),
  });

  return { staker, proxyAdminOwner };
};

async function upgradeStakerContract(proxyAdminOwner) {
  // Impersonate proxy admin owner
  await impersonateAccount(proxyAdminOwner);
  const proxyAdminSigner = await ethers.provider.getSigner(proxyAdminOwner);
  const [deployer] = await ethers.getSigners();

  // Transfer proxy admin ownership to deployer
  await upgrades.admin.transferProxyAdminOwnership(
    constants.STAKER_ADDRESS[constants.CHAIN_ID.SEPOLIA],
    deployer.address,
    proxyAdminSigner,
  );

  // Upgrade the contract
  const stakerFactory = await ethers.getContractFactory("TruStakePOL");
  const stakerAddress = constants.STAKER_ADDRESS[constants.CHAIN_ID.SEPOLIA];

  const contract = await upgrades.upgradeProxy(stakerAddress, stakerFactory, {
    unsafeAllowRenames: true,
    kind: "transparent",
  });
  await contract.waitForDeployment();

  // Access upgraded staker contract via the new ABI
  const upgradedStaker = await ethers.getContractAt(
    constants.STAKER_ABI,
    constants.STAKER_ADDRESS[constants.CHAIN_ID.SEPOLIA],
  );

  return upgradedStaker;
}
