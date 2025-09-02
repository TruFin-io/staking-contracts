import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import * as dotenv from "dotenv";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";

dotenv.config({ path: "../../.env" });

export default {
  mocha: {
    timeout: 120000,
  },
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 125,
      },
      evmVersion: "cancun",
    },
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC,
      chainId: 11155111,
      // gas: 180_000_000, // 200_000_000
      // gasLimit: 180_000_000, // 200_000_000
      // gasPrice: 8_000_000_000, // 400_000_000_000
      accounts: [process.env.DEPLOYER_PK],
    },
    mainnet: {
      url: process.env.MAINNET_RPC,
      chainId: 1,
      gas: 5_000_000,
      gasPrice: 10_000_000_000,
      accounts: [process.env.DEPLOYER_PK],
    },
    hardhat: {
      forking: {
        //Due to RPC error using Mainnet RPC
        url: process.env.SEPOLIA_RPC,
        // block before checkpoint submitted
        blockNumber: 6562465,
      },
      accounts: {
        privateKey: [process.env.DEPLOYER_PK],
      },
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API,
  },
  sourcify: {
    enabled: false,
  },
  gasReporter: {
    // enabled: true,
  },
  abiExporter: {
    path: "../../abis/pol-staker",
    runOnCompile: true,
    clear: true,
    flat: true,
    only: [":TruStakePOL"],
    spacing: 2,
    format: "json", // minimal
  },
};
