// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.28;

import {Withdrawal, Validator} from "./Types.sol";

/// @title TruStakePOLStorage
abstract contract TruStakePOLStorage {
    /// @custom:storage-location erc7201:trufin.storage.TruStakePOL
    struct TruStakePOLStorageStruct {
        /// @notice The treasury gathers fees during the restaking of rewards as shares.
        address _treasuryAddress;
        /// @notice Size of fee taken on rewards.
        /// @dev Fee in basis points.
        uint16 _fee;
        /// @notice Address of POL on this chain (Ethereum and Sepolia supported).
        address _stakingTokenAddress;
        /// @notice The stake manager contract deployed by Polygon.
        address _stakeManagerContractAddress;
        /// @notice The address of the default validator.
        address _defaultValidatorAddress;
        /// @notice The whitelist contract keeps track of what users can interact with
        ///   certain function in the TruStakePOL contract.
        address _whitelistAddress;
        /// @notice Value to offset rounding errors.
        uint256 _epsilon;
        /// @notice Cap on the smallest amount one can deposit to the staker.
        uint256 _minDeposit;
        /// @notice Mapping of a validator address to the validator struct.
        mapping(address => Validator) _validators;
        /// @notice The array of validators share contract addresses configured in the contract.
        address[] _validatorAddresses;
        /// @notice Mapping to keep track of the withdrawals (user, amount) for each unbond nonce for each validator.
        mapping(address => mapping(uint256 => Withdrawal)) _withdrawals;
        /// @notice Address of the POL delegate registry contract.
        address _delegateRegistry;
    }
}
