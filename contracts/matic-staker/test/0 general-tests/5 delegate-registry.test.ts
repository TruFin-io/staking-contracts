import { BigNumber } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import * as constants from "../helpers/constants";
import { deployment } from "../helpers/fixture";
import { ethers } from "hardhat";
import { FakeContract, smock } from "@defi-wonderland/smock";
import chai from "chai";

chai.use(smock.matchers);

describe("Call delegate registry", () => {
  let one, two, staker;
  let delegateRegistry: FakeContract;

  beforeEach(async () => {
    // reset to fixture
    ({ one, two, staker } = await loadFixture(deployment));
    delegateRegistry = await smock.fake(constants.DELEGATE_REGISTRY_ABI);
    await staker.setDelegateRegistry(delegateRegistry.address);
  });

  describe("setGovernanceDelegation", async () => {
    it("Clears delegation with no delegates", async () => {
      await staker.setGovernanceDelegation("test", [], 123);
      expect(delegateRegistry.clearDelegation).to.have.been.called;
    });

    it("Sets delegate", async () => {
      const delegations = [
        [ethers.utils.hexZeroPad(one.address, 32), BigNumber.from(1)],
        [ethers.utils.hexZeroPad(two.address, 32), BigNumber.from(2)]
      ];

      await staker.setGovernanceDelegation("test", delegations, 123);
      expect(delegateRegistry.setDelegation).to.have.been.called;
    });
  });
});
