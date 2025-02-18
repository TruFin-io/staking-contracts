import { ethers, upgrades, network } from "hardhat";
const clc = require("cli-color");

const contractName = "MasterWhitelist";

// This script will deploy the contract implementation, proxy and proxy admin.
async function main() {
  const chainID = network.config.chainId;
  if (!process.env.KEYRING_CHECKER) {
    throw new Error("KEYRING_CHECKER environment variable is not set");
  }
  if (!process.env.KEYRING_POLICY_ID) {
    throw new Error("KEYRING_POLICY_ID environment variable is not set");
  }
  const keyringCheckerAddress = process.env.KEYRING_CHECKER;
  const keyringPolicyId = ethers.BigNumber.from(process.env.KEYRING_POLICY_ID);

  console.log(`Chain ID: ${chainID}`);
  console.log(`Keyring Checker Address: ${keyringCheckerAddress}`);
  console.log(`Keyring Policy ID: ${keyringPolicyId}`);

  // Load the contract proxy and await deployment.
  const contractFactory = await ethers.getContractFactory(contractName);
  const contract = await upgrades.deployProxy(contractFactory, [keyringCheckerAddress, keyringPolicyId]);
  await contract.deployed();

  console.log(contract);

  // Log the deployed address and verification instructions.
  console.log(`${contractName} deployed at ${contract.address}`);
  console.log(`Verify with:`);
  console.log(clc.blackBright(`npx hardhat verify ${contract.address} --network ${network.name}`));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
