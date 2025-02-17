import { ethers, network, upgrades } from "hardhat";
const clc = require("cli-color");

const contractName = "MasterWhitelist";

// This script will deploy the contract implementation and update the proxy.
async function main() {
  let contractAddress: string;

  if (process.env.CONTRACT !== undefined) {
    contractAddress = process.env.CONTRACT;
  } else throw Error("The address of the contract to upgrade should be specified by passing a CONTRACT variable.");

  const keyringCheckerAddress = process.env.KEYRING_CHECKER_ADDRESS;
  const keyringPolicyId = process.env.KEYRING_POLICY_ID;

  console.log(`Keyring Checker Address: ${keyringCheckerAddress}`);
  console.log(`Keyring Policy ID: ${keyringPolicyId}`);

  // Load the contract proxy and await deployment.
  const contractFactory = await ethers.getContractFactory(contractName);
  let contract = await upgrades.upgradeProxy(contractAddress, contractFactory, {});

  // Non atomic operation as initializer cannot be called on an already initialized contract.
  await contract.setKeyringConfiguration(keyringCheckerAddress, keyringPolicyId);

  await contract.deployed();

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
