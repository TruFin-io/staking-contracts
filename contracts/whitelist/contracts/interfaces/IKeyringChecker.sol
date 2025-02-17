// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

/// @title Keyring Checker Interface
/// @notice Interface for a contract that checks credentials against a Keyring contract.
interface IKeyringChecker {
    /**
     * @notice Checks if an entity has a valid credential and supports legacy interface.
     * @param policyId The ID of the policy.
     * @param entity_ The address of the entity to check.
     * @return True if the entity has a valid credential, false otherwise.
     */
    function checkCredential(address entity_, uint32 policyId) external view returns (bool);
}
