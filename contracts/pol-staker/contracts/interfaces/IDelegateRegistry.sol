// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

/// @title Delegate Registry Interface
/// @notice Interface for a contract that manages POL voting delegations.
interface IDelegateRegistry {
    struct Delegation {
        bytes32 delegate;
        uint256 ratio;
    }

    // --- Functions ---

    /// @notice Sets a delegate for the msg.sender and a specific context.
    /// @param context ID of the context in which delegation should be set.
    /// @param delegation Array of delegations. Must be sorted in numerical order, from smallest to largest.
    /// @param expirationTimestamp Unix timestamp at which this delegation should expire.
    /// @notice setDelegation() will overwrite the user's previous delegation for the given context.
    function setDelegation(string memory context, Delegation[] memory delegation, uint256 expirationTimestamp)
        external;

    /// @notice Clears msg.sender's delegation in a given context.
    /// @param context ID of the context in which delegation should be cleared.
    function clearDelegation(string memory context) external;
}
