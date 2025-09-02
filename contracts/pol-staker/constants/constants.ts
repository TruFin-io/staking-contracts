// --- Chain Config ---

export enum CHAIN_ID {
  ETH_MAINNET = 1,
  SEPOLIA = 11155111,
}

export const DEFAULT_CHAIN_ID = 1;

// --- Constructor Arguments ---

// Account addresses
// Most of Polygon's addresses can be found at https://docs.polygon.technology/pos/reference/contracts/genesis-contracts/

export const TREASURY_ADDRESS = {
  [CHAIN_ID.ETH_MAINNET]: "0x8680173376b74E50C8e81A2b461252EfFEC922b3", // << correct according to gnosis safe // other: "0xDbE6ACf2D394DBC830Ed55241d7b94aaFd2b504D"
  [CHAIN_ID.SEPOLIA]: "0xa262FbF18d19477325228c2bB0c3f9508098287B", // same as the Sepolia reserves Safe
};

// Contract addresses
export const STAKING_TOKEN_ADDRESS = {
  [CHAIN_ID.ETH_MAINNET]: "0x455e53CBB86018Ac2B8092FdCd39d8444aFFC3F6", // correct according to etherscan
  [CHAIN_ID.SEPOLIA]: "0x44499312f493F62f2DFd3C6435Ca3603EbFCeeBa",
};

export const STAKE_MANAGER_CONTRACT_ADDRESS = {
  [CHAIN_ID.ETH_MAINNET]: "0x5e3Ef299fDDf15eAa0432E6e66473ace8c13D908", // correct according to validator share contract
  [CHAIN_ID.SEPOLIA]: "0x4AE8f648B1Ec892B6cc68C89cc088583964d08bE",
};

export const VALIDATOR_SHARE_CONTRACT_ADDRESS = {
  [CHAIN_ID.ETH_MAINNET]: "0xeA077b10A0eD33e4F68Edb2655C18FDA38F84712", // twinstake validator
  [CHAIN_ID.SEPOLIA]: "0xE50F5ad9b885675FD11D8204eB01C83a8a32a91D", // validator id: 1
};

export const WHITELIST_ADDRESS = {
  [CHAIN_ID.ETH_MAINNET]: "0x5701773567A4A903eF1DE459D0b542AdB2439937", // constants.AddressZero,
  [CHAIN_ID.SEPOLIA]: "0x9B46d57ebDb35aC2D59AB500F69127Bb24DA62b1",
};

export const DELEGATE_REGISTRY_CONTRACT_ADDRESS = {
  [CHAIN_ID.ETH_MAINNET]: "0xb83EEf820AeC27E443D23cdCd6F383aBFa419ff9",
  [CHAIN_ID.SEPOLIA]: "0x32Bb2dB7826cf342743fe80832Fe4DF725879C2D",
};

// Other args
export const EPSILON = 10000n;

export const FEE = 1000n;

export const FEE_PRECISION = 10000n;

export const NAME = "TruStake POL Vault Shares";

export const SYMBOL = "TruPOL";
