// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.28;

/// @notice Struct to hold information on a user's withdrawal request for fair claiming.
/// @dev The epoch of withdrawal is not stored as that is the key in the `unbondingWithdrawals`
/// mapping.
/// @param user The user that made the withdrawal request.
/// @param amount The amount of POL that the user requested to withdraw.
struct Withdrawal {
    address user;
    uint256 amount;
}

/// @notice Struct to track information on a validator.
/// @param state The state of the validator.
/// @param stakedAmount The amount of POL staked on the validator. This is the maximum that can be withdrawn from this validator.
/// @param validatorAddress The address of the validator.
struct Validator {
    ValidatorState state;
    uint256 stakedAmount;
    address validatorAddress;
}

/// @notice Enum for the possible validator states.
enum ValidatorState {
    NONE,
    ENABLED,
    DISABLED
}

/// @notice Struct to hold staker information.
struct StakerInfo {
    address stakingTokenAddress;
    address stakeManagerContractAddress;
    address treasuryAddress;
    address defaultValidatorAddress;
    address whitelistAddress;
    address delegateRegistry;
    uint256 epsilon;
    uint256 fee;
    uint256 minDeposit;
}
