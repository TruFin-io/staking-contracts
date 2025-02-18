import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

require("dotenv").config({ path: "../../.env" });
require("hardhat-contract-sizer");
require("hardhat-abi-exporter");

export default {
  solidity: "0.8.19",
  settings: {
    optimizer: {
      enabled: false,
      runs: 1000
    }
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC,
      chainId: 11155111,
      // gas: 180_000_000,
      // gasPrice: 40_000_000_000,
      accounts: [process.env.DEPLOYER_PK],
      env: {
        KEYRING_CHECKER: process.env.KEYRING_CHECKER_ADDRESS_SEPOLIA,
        KEYRING_POLICY_ID: process.env.KEYRING_POLICY_ID_SEPOLIA
      }
    },
    mumbai: {
      url: process.env.MUMBAI_RPC,
      chainId: 80001,
      // gas: 180_000_000,
      // gasPrice: 8_000_000_000,
      accounts: [process.env.DEPLOYER_PK],
      env: {
        KEYRING_CHECKER: process.env.KEYRING_CHECKER_ADDRESS_MUMBAI,
        KEYRING_POLICY_ID: process.env.KEYRING_POLICY_ID_MUMBAI
      }
    },
    mainnet: {
      url: process.env.MAINNET_RPC,
      chainId: 1,
      // gas: 2_200_000,
      // gasPrice: 6_000_000_000,
      accounts: [process.env.DEPLOYER_PK],
      env: {
        KEYRING_CHECKER: process.env.KEYRING_CHECKER_ADDRESS_MAINNET,
        KEYRING_POLICY_ID: process.env.KEYRING_POLICY_ID_MAINNET
      }
    },
    polygon: {
      url: process.env.POLYGON_RPC,
      chainId: 137,
      // gas: 180_000_000,
      // gasPrice: 8_000_000_000,
      accounts: [process.env.DEPLOYER_PK],
      env: {
        KEYRING_CHECKER: process.env.KEYRING_CHECKER_ADDRESS_POLYGON,
        KEYRING_POLICY_ID: process.env.KEYRING_POLICY_ID_POLYGON
      }
    }
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API
  },
  gasReporter: {
    // enabled: true,
  },
  abiExporter: {
    path: "../../abis/whitelist",
    runOnCompile: true,
    clear: true,
    flat: true,
    only: [":MasterWhitelist"],
    spacing: 2,
    format: "json" // minimal
  }
};
