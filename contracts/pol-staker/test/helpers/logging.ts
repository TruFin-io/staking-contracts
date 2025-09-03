/** Loggers useful for debugging and locating storage slots in smart contracts */
import * as helpers from "@nomicfoundation/hardhat-network-helpers";
import { BigNumber, Contract } from "ethers";

export const logStorageIndices = async (stakeManager: Contract): Promise<void> => {
  console.log(stakeManager.address);
  console.log(await stakeManager.currentEpoch());

  for (let i = 0; i < 50; i++) {
    const r1 = await helpers.getStorageAt(stakeManager.address, i);
    console.log(i, BigNumber.from(r1));
  }
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const logAddresses = (accts: Record<string, any>): void => {
  const addrs = Object.fromEntries(Object.entries(accts).map(([k, v]) => [k, v.address]));
  console.log(addrs);
};
