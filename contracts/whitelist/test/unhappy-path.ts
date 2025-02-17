import { ethers, network, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract } from "ethers";
import { AddressZero } from "@ethersproject/constants";

describe("UNHAPPY PATH", () => {
  let whitelist: Contract;
  let owner;
  let agent;
  let user;

  before(async function () {
    [owner, agent, user] = await ethers.getSigners();

    // Deploy a mocked keyring checker for testing purposes
    const keyringCheckerFactory = await ethers.getContractFactory("MockedKeyringChecker");
    const keyringChecker = await keyringCheckerFactory.deploy();
    const keyringPolicyId = 1; // Just a random policy id non-zero

    // Deploy the whitelist contract
    const whiteListFactory = await ethers.getContractFactory("MasterWhitelist");
    whitelist = await upgrades.deployProxy(whiteListFactory, [keyringChecker.address, keyringPolicyId]);
  });

  beforeEach(async () => {
    // create agent
    whitelist.connect(owner).addAgent(agent.address);
  });

  it("should fail when being initialized again", async function () {
    await expect(whitelist.initialize(AddressZero, 0)).to.be.revertedWith(
      "Initializable: contract is already initialized"
    );
  });

  it("addAgent should revert if not called by the agent", async function () {
    await expect(whitelist.connect(user).addAgent(user.address)).to.be.revertedWithCustomError(
      whitelist,
      "CallerIsNotAnAgent"
    );

    expect(await whitelist.isAgent(user.address)).equal(false);
  });

  it("addAgent should revert if adding an existing agent", async function () {
    await expect(whitelist.connect(owner).addAgent(agent.address)).to.be.revertedWithCustomError(
      whitelist,
      "UserAlreadyAnAgent"
    );

    expect(await whitelist.isAgent(agent.address)).equal(true);
  });

  it("addAgent should revert if adding owner", async function () {
    await expect(whitelist.connect(agent).addAgent(owner.address)).to.be.revertedWithCustomError(
      whitelist,
      "CannotAddOwner"
    );

    expect(await whitelist.isAgent(owner.address)).equal(true);
  });

  it("removeAgent should revert if not called by the agent", async function () {
    await expect(whitelist.connect(user).removeAgent(agent.address)).to.be.revertedWithCustomError(
      whitelist,
      "CallerIsNotAnAgent"
    );

    expect(await whitelist.isAgent(agent.address)).equal(true);
  });

  it("removeAgent should revert if trying to remove owner", async function () {
    await expect(whitelist.connect(agent).removeAgent(owner.address)).to.be.revertedWithCustomError(
      whitelist,
      "CannotRemoveOwner"
    );

    expect(await whitelist.isAgent(owner.address)).equal(true);
  });

  it("removeAgent should revert if trying to remove non-agent", async function () {
    await expect(whitelist.connect(agent).removeAgent(user.address)).to.be.revertedWithCustomError(
      whitelist,
      "UserIsNotAnAgent"
    );

    expect(await whitelist.isAgent(user.address)).equal(false);
  });

  it("should revert if a non-agent is trying to whitelist a user", async function () {
    await expect(whitelist.connect(user).whitelistUser(user.address)).to.be.revertedWithCustomError(
      whitelist,
      "CallerIsNotAnAgent"
    );

    expect(await whitelist.connect(agent).isUserWhitelisted(user.address)).to.equal(false);
  });

  it("should revert if a non-agent is trying to blacklist a user", async function () {
    await expect(whitelist.connect(user).blacklistUser(user.address)).to.be.revertedWithCustomError(
      whitelist,
      "CallerIsNotAnAgent"
    );

    expect(await whitelist.connect(agent).isUserBlacklisted(user.address)).to.equal(false);
  });

  it("should revert if a non-agent is trying to clear a user's whitelisting status", async function () {
    await whitelist.connect(agent).blacklistUser(user.address);

    await expect(whitelist.connect(user).clearWhitelistStatus(user.address)).to.be.revertedWithCustomError(
      whitelist,
      "CallerIsNotAnAgent"
    );

    expect(await whitelist.connect(agent).isUserBlacklisted(user.address)).to.equal(true);
  });

  it("should revert if trying to whitelist an already whitelisted user", async function () {
    await whitelist.connect(agent).whitelistUser(user.address);

    await expect(whitelist.connect(agent).whitelistUser(user.address)).to.be.revertedWithCustomError(
      whitelist,
      "UserAlreadyWhitelisted"
    );
  });

  it("should revert if trying to blacklist an already blacklisted user", async function () {
    await whitelist.connect(agent).blacklistUser(user.address);

    await expect(whitelist.connect(agent).blacklistUser(user.address)).to.be.revertedWithCustomError(
      whitelist,
      "UserAlreadyBlacklisted"
    );
  });

  it("should revert if trying to clear an already cleared whitelisting status", async function () {
    await whitelist.connect(agent).clearWhitelistStatus(user.address);

    await expect(whitelist.connect(agent).clearWhitelistStatus(user.address)).to.be.revertedWithCustomError(
      whitelist,
      "WhitelistingStatusAlreadyCleared"
    );
  });

  it("should revert if trying to set keyring configuration if not an agent", async function () {
    await expect(whitelist.connect(user).setKeyringConfiguration(AddressZero, 0)).to.be.revertedWithCustomError(
      whitelist,
      "CallerIsNotAnAgent"
    );
  });
});
