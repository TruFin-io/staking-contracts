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
   const contractFactory = await ethers.getContractFactory(contractName);
   console.log("Upgrading contract...");
   let contract = await upgrades.upgradeProxy(contractAddress, contractFactory, {});
   console.log("Waiting for upgrade transaction...");
   await contract.deployed();

   // Non atomic operation as initializer cannot be called on an already initialized contract.
   console.log("Setting keyring configuration...");
   const tx = await contract.setKeyringConfiguration(keyringCheckerAddress, keyringPolicyId);
   console.log("Waiting for configuration transaction...");
   const receipt = await tx.wait();
   
   if (!receipt.status) {
     throw new Error("Failed to set keyring configuration");
   }

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
