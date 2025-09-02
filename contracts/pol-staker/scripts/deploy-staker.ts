import { ethers, network, upgrades } from "hardhat";

import {
  DELEGATE_REGISTRY_CONTRACT_ADDRESS,
  FEE,
  STAKE_MANAGER_CONTRACT_ADDRESS,
  STAKING_TOKEN_ADDRESS,
  TREASURY_ADDRESS,
  VALIDATOR_SHARE_CONTRACT_ADDRESS,
  WHITELIST_ADDRESS,
} from "../constants/constants";

// eslint-disable-next-line @typescript-eslint/no-var-requires
const clc = require("cli-color");

const contractName = "TruStakePOL";

// This script will deploy the contract implementation, proxy and proxy admin.
async function main() {
  const chainId = network.config.chainId;
  console.log(`Deploying ${contractName} on chain ID ${chainId}.`);

  // Specify constructor args.
  const args = [
    STAKING_TOKEN_ADDRESS[chainId],
    STAKE_MANAGER_CONTRACT_ADDRESS[chainId],
    VALIDATOR_SHARE_CONTRACT_ADDRESS[chainId],
    WHITELIST_ADDRESS[chainId],
    TREASURY_ADDRESS[chainId],
    DELEGATE_REGISTRY_CONTRACT_ADDRESS[chainId],
    FEE,
  ];
  console.log(args);

  // Load the contract proxy and await deployment.
  const contractFactory = await ethers.getContractFactory(contractName);
  const contract = await upgrades.deployProxy(contractFactory, args);
  await contract.waitForDeployment();

  console.log(contract);

  // Log the deployed address and verification instructions.
  console.log(`${contractName} deployed at ${await contract.getAddress()}`);
  console.log(`Verify with:`);
  console.log(clc.blackBright(`npx hardhat verify ${await contract.getAddress()} --network ${network.name}`));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
