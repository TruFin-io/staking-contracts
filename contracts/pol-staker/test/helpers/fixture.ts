/** Helper file exporting a testing fixture for fresh deployments. */
import { ethers, network, upgrades } from "hardhat";
import { HardhatNetworkConfig } from "hardhat/types";

import * as constants from "../helpers/constants";
import { parseEther } from "./math";
import { setTokenBalancesAndApprove, whitelistUsers } from "./state-interaction";

export const deployment = async () => {
  // reset hardhat network to fork from Sepolia
  const config = network.config as HardhatNetworkConfig;
  await ethers.provider.send("hardhat_reset", [
    {
      forking: {
        jsonRpcUrl: process.env.SEPOLIA_RPC,
        blockNumber: config.forking?.blockNumber,
      },
    },
  ]);

  // load deployed contracts
  const token = await ethers.getContractAt(
    constants.STAKING_TOKEN_ABI,
    constants.STAKING_TOKEN_ADDRESS[constants.DEFAULT_CHAIN_ID],
  );

  const validatorShare = await ethers.getContractAt(
    constants.VALIDATOR_SHARE_ABI,
    constants.VALIDATOR_SHARE_CONTRACT_ADDRESS[constants.DEFAULT_CHAIN_ID],
  );

  const validatorShare2 = await ethers.getContractAt(
    constants.VALIDATOR_SHARE_ABI,
    constants.VALIDATOR_SHARE_2_CONTRACT_ADDRESS[constants.DEFAULT_CHAIN_ID],
  );

  const stakeManager = await ethers.getContractAt(
    constants.STAKE_MANAGER_ABI,
    constants.STAKE_MANAGER_CONTRACT_ADDRESS[constants.DEFAULT_CHAIN_ID],
  );

  const delegateRegistry = await ethers.getContractAt(
    constants.DELEGATE_REGISTRY_ABI,
    constants.DELEGATE_REGISTRY_CONTRACT_ADDRESS[constants.DEFAULT_CHAIN_ID],
  );

  // load signers, balances set to 10k ETH in hardhat config file
  const [deployer, treasury, one, two, three, four, five, nonWhitelistedUser] = await ethers.getSigners();

  // mock whitelist
  const whitelist = await ethers.getContractAt(
    constants.WHITELIST_ABI,
    constants.WHITELIST_ADDRESS[constants.DEFAULT_CHAIN_ID],
  );

  const stakerFactory = await ethers.getContractFactory("TruStakePOL");

  const staker = await upgrades.deployProxy(
    stakerFactory,
    [
      await token.getAddress(),
      await stakeManager.getAddress(),
      await validatorShare.getAddress(),
      await whitelist.getAddress(),
      treasury.address,
      await delegateRegistry.getAddress(),
      constants.FEE,
    ],
    {
      redeployImplementation: "always",
    },
  );

  // make it the default validator
  await staker.setDefaultValidator(validatorShare);

  // set each balance to 10M POL and approve it to staker
  await setTokenBalancesAndApprove(
    token,
    [treasury, one, two, three, four, five, nonWhitelistedUser],
    await staker.getAddress(),
    parseEther(10e6),
  );

  // fund the whitelist owner
  const whitelistOwner = await whitelist.owner();
  await deployer.sendTransaction({
    to: whitelistOwner,
    value: ethers.parseEther("1"),
  });

  // add all users to whitelist
  await whitelistUsers(whitelist, [deployer, treasury, one, two, three, four, five]);

  return {
    deployer,
    treasury,
    one,
    two,
    three,
    four,
    five,
    nonWhitelistedUser, // accounts
    token,
    validatorShare,
    validatorShare2,
    stakeManager,
    whitelist,
    staker,
    delegateRegistry, // contracts
  };
};
