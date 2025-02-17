// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IMasterWhitelist} from "../interfaces/IMasterWhitelist.sol";
import {IKeyringChecker} from "../interfaces/IKeyringChecker.sol";
/// @title Master Whitelist
/// @notice Contract that manages a whitelist of users.
contract MasterWhitelist is OwnableUpgradeable, IMasterWhitelist {
    /// @notice List of agents, who are in charge of managing the whitelist.
    mapping(address => bool) public agents;

    /// @notice Whitelist for users.
    mapping(address => WhitelistingStatus) public users;

    /// @notice The address of the Keyring contract.
    /// @dev This could have been immutable, but not possible in upgradeable contracts.
    /// @dev Consumes one storage slot.
    IKeyringChecker public keyringChecker;

    /// @notice The policyId to use with the Keyring contract.
    /// @dev This could have been immutable, but not possible in upgradeable contracts.
    /// @dev Consumes one storage slot.
    uint32 public policyId;

    /// @notice Gap for upgradeability.
    /// @dev Two storage slots taken by keyringChecker and policyId.
    uint256[48] private __gap;

    // No storage variables should be removed or modified since this is an upgradeable contract.
    // It is safe to add new ones as long as they are declared after the existing ones.

    /// @notice Requires that the transaction sender is an agent.
    modifier onlyAgent() {
        if (!isAgent(msg.sender)) {
            revert CallerIsNotAnAgent();
        }
        _;
    }

    /// @dev https://docs.openzeppelin.com/contracts/4.x/api/proxy#Initializable-_disableInitializers--
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializer for the whitelist.
    function initialize(address _keyringChecker, uint32 _policyId) external initializer {
        __Ownable_init();
        keyringChecker = IKeyringChecker(_keyringChecker);
        policyId = _policyId;
    }

    /// @dev Returns true if `account` has permission to hold and transfer tokens.
    /// @dev By default Morpho and Bundler have this permission.
    /// @dev Override this function to change the permissioning scheme.
    function hasPermission(address account) public view virtual returns (bool) {
        // Keyring is turned on, so perform Keyring checks
        Keyring k = Keyring(KEYRING);
        return k.checkCredential(POLICYID, account);
    }

    /// @notice Adds an agent to the list of agents.
    /// @param _agent The address of the agent.
    function addAgent(address _agent) external onlyAgent {
        if (_agent == owner()) {
            revert CannotAddOwner();
        }

        if (agents[_agent]) {
            revert UserAlreadyAnAgent();
        }

        agents[_agent] = true;

        emit AgentAdded(_agent);
    }

    /// @notice Removes an agent from the list of agents.
    /// @param _agent The address of the agent.
    function removeAgent(address _agent) external onlyAgent {
        if (_agent == owner()) {
            revert CannotRemoveOwner();
        }

        if (!agents[_agent]) {
            revert UserIsNotAnAgent();
        }

        delete agents[_agent];

        emit AgentRemoved(_agent);
    }

    /// @notice Whitelists a user.
    /// @param _user The address of the user.
    function whitelistUser(address _user) external onlyAgent {
        if (users[_user] == WhitelistingStatus.Whitelisted) {
            revert UserAlreadyWhitelisted();
        }

        emit WhitelistingStatusChanged(_user, users[_user], WhitelistingStatus.Whitelisted);

        users[_user] = WhitelistingStatus.Whitelisted;
    }

    /// @notice Blacklists a user.
    /// @param _user The address of the user.
    function blacklistUser(address _user) external onlyAgent {
        if (users[_user] == WhitelistingStatus.Blacklisted) {
            revert UserAlreadyBlacklisted();
        }

        emit WhitelistingStatusChanged(_user, users[_user], WhitelistingStatus.Blacklisted);

        users[_user] = WhitelistingStatus.Blacklisted;
    }

    /// @notice Clear the whitelist status for the user.
    /// @param _user The address of the user.
    function clearWhitelistStatus(address _user) external onlyAgent {
        if (users[_user] == WhitelistingStatus.None) {
            revert WhitelistingStatusAlreadyCleared();
        }

        emit WhitelistingStatusChanged(_user, users[_user], WhitelistingStatus.None);

        users[_user] = WhitelistingStatus.None;
    }

    /// @notice Checks if a user is whitelisted.
    /// @param _user The address to check.
    /// @return A value indicating whether this user is whitelisted.
    function isUserWhitelisted(address _user) external view returns (bool) {
        return users[_user] == WhitelistingStatus.Whitelisted || hasPermission(_user);
    }

    /// @notice Checks if a user is blacklisted.
    /// @param _user The address to check.
    /// @return A value indicating whether this user is blacklisted.
    function isUserBlacklisted(address _user) public view returns (bool) {
        return users[_user] == WhitelistingStatus.Blacklisted;
    }

    /// @notice Checks if this address is an agent.
    /// @param _agent The address to check.
    /// @dev The owner is always an agent.
    /// @return A value indicating whether this address is that of an agent.
    function isAgent(address _agent) public view returns (bool) {
        return agents[_agent] || _agent == owner();
    }
}
