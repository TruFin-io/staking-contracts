import { ethers, network, upgrades } from "hardhat";

// eslint-disable-next-line @typescript-eslint/no-var-requires
const clc = require("cli-color");

const contractName = "TruStakePOL";

// This script will deploy the contract implementation and update the proxy.
async function main() {
  let contractAddress: string;

  if (process.env.CONTRACT !== undefined) {
    contractAddress = process.env.CONTRACT;
  } else throw Error("The address of the contract to upgrade should be specified by passing a CONTRACT variable.");

  // Load the contract proxy and await deployment.
  const contractFactory = await ethers.getContractFactory(contractName);
  const contract = await upgrades.upgradeProxy(contractAddress, contractFactory, { unsafeAllowRenames: true });
  await contract.waitForDeployment();

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
