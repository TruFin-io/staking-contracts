// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {CommonBase} from "forge-std/Base.sol";
import {StdStorage, stdStorage} from "forge-std/StdStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ValidatorState, Withdrawal, Validator} from "../../../contracts/main/Types.sol";

/// @title BaseStorageUtils
/// @notice Contains common utility functions for reading and writing to storage.
abstract contract BaseStorageUtils is CommonBase {
    uint16 internal constant MASK_16_BITS = 0xFFFF; // (1 << 16) - 1
    uint160 internal constant MASK_160_BITS = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // (1 << 160) - 1

    address internal storageTarget;
}

/// @title ERC20StorageUtils
/// @notice Reads and writes to ERC20Upgradeable storage directly using Foundry vm.
abstract contract ERC20StorageUtils is BaseStorageUtils {
    using stdStorage for StdStorage;

    /// @dev Storage root per ERC20 for `openzeppelin.storage.ERC20`
    bytes32 private constant _STORAGE_SLOT = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function getERC20StorageSlot() internal pure returns (bytes32) {
        return _STORAGE_SLOT;
    }

    // --- Getters ---

    function readTotalSupply() internal returns (uint256) {
        return stdstore.target(address(storageTarget)).sig(IERC20.totalSupply.selector).read_uint();
    }

    function readBalanceOf(address user) public returns (uint256) {
        return stdstore.target(storageTarget).sig(IERC20.balanceOf.selector).with_key(user).read_uint();
    }

    function readAllowance(address owner, address spender) public returns (uint256) {
        return
            stdstore.target(storageTarget).sig(IERC20.allowance.selector).with_key(owner).with_key(spender).read_uint();
    }

    // --- Setters ---

    function writeTotalSupply(uint256 newSupply) public {
        stdstore.target(storageTarget).sig(IERC20.totalSupply.selector).checked_write(newSupply);
    }

    function writeBalanceOf(address user, uint256 balance) public {
        stdstore.target(storageTarget).sig(IERC20.balanceOf.selector).with_key(user).checked_write(balance);
    }

    function writeAllowance(address owner, address spender, uint256 amount) public {
        stdstore.target(storageTarget).sig(IERC20.allowance.selector).with_key(owner).with_key(spender).checked_write(
            amount
        );
    }

    function increaseUserBalance(address user, uint256 amount) public {
        writeBalanceOf(user, readBalanceOf(user) + amount);
    }

    function increaseTotalSupply(uint256 amount) public {
        writeTotalSupply(readTotalSupply() + amount);
    }
}

/// @title TruStakePOLStorageUtils
/// @notice Reads and writes to TruStakePOL storage directly using Foundry vm.
abstract contract TruStakePOLStorageUtils is BaseStorageUtils {
    /// @dev Storage root per ERC7201 for `trufin.storage.TruStakePOL`
    bytes32 private constant _STORAGE_SLOT = 0x2d27943992ce797a3601911eb0653a18c3311f54cf95fc9eb4503583f50b2300;

    function getTruStakePOLStorageSlot() internal pure returns (bytes32) {
        return _STORAGE_SLOT;
    }

    // --- Storage Slot Offsets ---
    uint256 private constant _SLOT_PACKED_0 = 0; // _treasuryAddress (160 bits), _fee (16)
    uint256 private constant _SLOT_STAKING_TOKEN = 1;
    uint256 private constant _SLOT_STAKE_MANAGER = 2;
    uint256 private constant _SLOT_DEFAULT_VALIDATOR = 3;
    uint256 private constant _SLOT_WHITELIST = 4;
    uint256 private constant _SLOT_EPSILON = 5;
    uint256 private constant _SLOT_MIN_DEPOSIT = 6;
    uint256 private constant _SLOT_VALIDATORS_MAPPING = 7;
    uint256 private constant _SLOT_VALIDATOR_ARRAY = 8;
    uint256 private constant _SLOT_WITHDRAWALS_MAPPING = 9;
    uint256 private constant _SLOT_DELEGATE_REGISTRY = 10;

    uint8 private constant _FEE_OFFSET = 160;

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 0 - TreasuryAddress, Fee
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readTreasuryAddress(address target) internal view returns (address treasury) {
        bytes32 slot = bytes32(uint256(_STORAGE_SLOT) + _SLOT_PACKED_0);
        uint256 raw = uint256(vm.load({target: target, slot: slot}));

        // Extract treasury address from lower 160 bits
        treasury = address(uint160(raw));
    }

    function readFee(address target) internal view returns (uint16) {
        // Get the packed slot containing treasury (160 bits), fee (16 bits)
        bytes32 slot = bytes32(uint256(_STORAGE_SLOT) + _SLOT_PACKED_0);
        uint256 raw = uint256(vm.load({target: target, slot: slot}));

        // Extract fee from bits 160-175 (16 bits)
        // Shift right by 160 to move fee to lower bits, then mask with 16-bit mask
        return uint16((raw >> _FEE_OFFSET) & MASK_16_BITS);
    }

    // --- Setters ---
    function writeTreasuryAddress(address target, address treasury) internal {
        // Get the packed slot containing treasury (160 bits), fee (16 bits)
        bytes32 slot = bytes32(uint256(_STORAGE_SLOT) + _SLOT_PACKED_0);
        uint256 raw = uint256(vm.load({target: target, slot: slot}));

        // Clear lower 160 bits (treasury address) while preserving fee
        uint256 masked = raw & ~MASK_160_BITS;

        // Set new treasury address in lower 160 bits
        uint256 updated = masked | uint256(uint160(treasury));

        // Store updated value back to storage
        vm.store({target: target, slot: slot, value: bytes32(updated)});
    }

    function writeFee(address target, uint16 fee) internal {
        // Get the packed slot containing treasury (160 bits), fee (16 bits)
        bytes32 slot = bytes32(uint256(_STORAGE_SLOT) + _SLOT_PACKED_0);
        uint256 raw = uint256(vm.load({target: target, slot: slot}));

        // Clear bits 160-175 (fee) while preserving treasury
        uint256 cleared = raw & ~(MASK_16_BITS << _FEE_OFFSET);

        // Set new fee in bits 160-175
        uint256 updated = cleared | (uint256(fee) << _FEE_OFFSET);

        // Store updated value back to storage
        vm.store({target: target, slot: slot, value: bytes32(updated)});
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 1 - Staking Token Address
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readStakingTokenAddress(address target) internal view returns (address) {
        return readAddressField(target, _SLOT_STAKING_TOKEN);
    }

    // --- Setters ---
    function writeStakingTokenAddress(address target, address value) internal {
        writeAddressField(target, _SLOT_STAKING_TOKEN, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 2 - Stake Manager Contract Address
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readStakeManagerContractAddress(address target) internal view returns (address) {
        return readAddressField(target, _SLOT_STAKE_MANAGER);
    }

    // --- Setters ---
    function writeStakeManagerContractAddress(address target, address value) internal {
        writeAddressField(target, _SLOT_STAKE_MANAGER, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 3 - Default Validator Address
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readDefaultValidatorAddress(address target) internal view returns (address) {
        return readAddressField(target, _SLOT_DEFAULT_VALIDATOR);
    }

    // --- Setters ---
    function writeDefaultValidatorAddress(address target, address value) internal {
        writeAddressField(target, _SLOT_DEFAULT_VALIDATOR, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 4 - Whitelist Address
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readWhitelistAddress(address target) internal view returns (address) {
        return readAddressField(target, _SLOT_WHITELIST);
    }

    // --- Setters ---
    function writeWhitelistAddress(address target, address value) internal {
        writeAddressField(target, _SLOT_WHITELIST, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 5 - Epsilon
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readEpsilon(address target) internal view returns (uint256) {
        return readUint256Field(target, _SLOT_EPSILON);
    }

    // --- Setters ---
    function writeEpsilon(address target, uint256 value) internal {
        writeUint256Field(target, _SLOT_EPSILON, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 6 - Min Deposit
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readMinDeposit(address target) internal view returns (uint256) {
        return readUint256Field(target, _SLOT_MIN_DEPOSIT);
    }

    // --- Setters ---
    function writeMinDeposit(address target, uint256 value) internal {
        writeUint256Field(target, _SLOT_MIN_DEPOSIT, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 7 - Validators Mapping
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readValidator(address target, address validator) internal view returns (Validator memory v) {
        bytes32 base = getValidatorSlot(validator);
        v.state = ValidatorState(uint8(uint256(vm.load({target: target, slot: base}))));
        v.stakedAmount = uint256(vm.load({target: target, slot: bytes32(uint256(base) + 1)}));
        v.validatorAddress = address(uint160(uint256(vm.load({target: target, slot: bytes32(uint256(base) + 2)}))));
    }

    // --- Setters ---

    function writeValidatorStakedAmount(address target, address validatorKey, uint256 stakedAmount) internal {
        bytes32 base = getValidatorSlot(validatorKey);
        vm.store({target: target, slot: bytes32(uint256(base) + 1), value: bytes32(stakedAmount)});
    }

    function writeValidator(address target, address validatorKey, Validator memory v) internal {
        bytes32 base = getValidatorSlot(validatorKey);
        vm.store({target: target, slot: base, value: bytes32(uint256(v.state))});
        vm.store({target: target, slot: bytes32(uint256(base) + 1), value: bytes32(v.stakedAmount)});
        vm.store({
            target: target,
            slot: bytes32(uint256(base) + 2),
            value: bytes32(uint256(uint160(v.validatorAddress)))
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 8 - Validator Addresses Array
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readValidatorAddressesLength(address target) internal view returns (uint256) {
        bytes32 lenSlot = bytes32(uint256(_STORAGE_SLOT) + _SLOT_VALIDATOR_ARRAY);
        return uint256(vm.load({target: target, slot: lenSlot}));
    }

    function readValidatorAddressAt(address target, uint256 index) internal view returns (address) {
        bytes32 slot = getValidatorAddressSlot(index);
        return address(uint160(uint256(vm.load({target: target, slot: slot}))));
    }

    // --- Setters ---
    function writeValidatorAddressesLength(address target, uint256 length) internal {
        bytes32 lenSlot = bytes32(uint256(_STORAGE_SLOT) + _SLOT_VALIDATOR_ARRAY);
        vm.store({target: target, slot: lenSlot, value: bytes32(length)});
    }

    function writeValidatorAddressAt(address target, uint256 index, address value) internal {
        bytes32 slot = getValidatorAddressSlot(index);
        vm.store({target: target, slot: slot, value: bytes32(uint256(uint160(value)))});
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 9 - Withdrawals Mapping
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readWithdrawal(address target, address validator, uint256 nonce)
        internal
        view
        returns (Withdrawal memory w)
    {
        bytes32 base = getWithdrawalSlot(validator, nonce);
        w.user = address(uint160(uint256(vm.load({target: target, slot: base}))));
        w.amount = uint256(vm.load({target: target, slot: bytes32(uint256(base) + 1)}));
    }

    // --- Setters ---
    function writeWithdrawal(address target, address validator, uint256 nonce, Withdrawal memory w) internal {
        bytes32 base = getWithdrawalSlot(validator, nonce);
        vm.store({target: target, slot: base, value: bytes32(uint256(uint160(w.user)))});
        vm.store({target: target, slot: bytes32(uint256(base) + 1), value: bytes32(w.amount)});
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   SLOT 10 - Delegate Registry
    //////////////////////////////////////////////////////////////////////////*/

    // --- Getters ---
    function readDelegateRegistry(address target) internal view returns (address) {
        return readAddressField(target, _SLOT_DELEGATE_REGISTRY);
    }

    // --- Setters ---
    function writeDelegateRegistry(address target, address value) internal {
        writeAddressField(target, _SLOT_DELEGATE_REGISTRY, value);
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   Generic Helper Functions
    //////////////////////////////////////////////////////////////////////////*/

    function readAddressField(address target, uint256 offset) internal view returns (address) {
        bytes32 slot = bytes32(uint256(_STORAGE_SLOT) + offset);
        return address(uint160(uint256(vm.load({target: target, slot: slot}))));
    }

    function writeAddressField(address target, uint256 offset, address value) internal {
        bytes32 slot = bytes32(uint256(_STORAGE_SLOT) + offset);
        vm.store({target: target, slot: slot, value: bytes32(uint256(uint160(value)))});
    }

    function readUint256Field(address target, uint256 offset) internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(_STORAGE_SLOT) + offset);
        return uint256(vm.load({target: target, slot: slot}));
    }

    function writeUint256Field(address target, uint256 offset, uint256 value) internal {
        bytes32 slot = bytes32(uint256(_STORAGE_SLOT) + offset);
        vm.store({target: target, slot: slot, value: bytes32(value)});
    }

    function getAddressArrayLengthSlot(address key, uint256 slotOffset) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, slotOffset + uint256(_STORAGE_SLOT)));
    }

    function getAddressArrayItemSlot(address key, uint256 index, uint256 slotOffset) internal pure returns (bytes32) {
        bytes32 location = getAddressArrayLengthSlot(key, slotOffset);
        return bytes32(uint256(location) + index);
    }

    function getValidatorSlot(address validator) internal pure returns (bytes32) {
        return keccak256(abi.encode(validator, _SLOT_VALIDATORS_MAPPING + uint256(_STORAGE_SLOT)));
    }

    function getValidatorAddressSlot(uint256 index) internal pure returns (bytes32) {
        bytes32 base = keccak256(abi.encode(uint256(_STORAGE_SLOT) + _SLOT_VALIDATOR_ARRAY));
        return bytes32(uint256(base) + index);
    }

    function getWithdrawalSlot(address validator, uint256 nonce) internal pure returns (bytes32) {
        bytes32 outer = keccak256(abi.encode(validator, _SLOT_WITHDRAWALS_MAPPING + uint256(_STORAGE_SLOT)));
        return keccak256(abi.encode(nonce, outer));
    }

    /*//////////////////////////////////////////////////////////////////////////
    //                   Overloaded Functions Using storageTarget
    //////////////////////////////////////////////////////////////////////////*/

    // --- SLOT 0 — Packed Access ---
    function readTreasuryAddress() internal view returns (address) {
        return readTreasuryAddress(storageTarget);
    }

    function readFee() internal view returns (uint16) {
        return readFee(storageTarget);
    }

    function writeTreasuryAddress(address treasury) internal {
        writeTreasuryAddress(storageTarget, treasury);
    }

    function writeFee(uint16 fee) internal {
        writeFee(storageTarget, fee);
    }

    // --- SLOT 1–4: Address Fields ---
    function readStakingTokenAddress() internal view returns (address) {
        return readStakingTokenAddress(storageTarget);
    }

    function readStakeManagerContractAddress() internal view returns (address) {
        return readStakeManagerContractAddress(storageTarget);
    }

    function readDefaultValidatorAddress() internal view returns (address) {
        return readDefaultValidatorAddress(storageTarget);
    }

    function readWhitelistAddress() internal view returns (address) {
        return readWhitelistAddress(storageTarget);
    }

    function readDelegateRegistry() internal view returns (address) {
        return readDelegateRegistry(storageTarget);
    }

    function writeStakingTokenAddress(address value) internal {
        writeStakingTokenAddress(storageTarget, value);
    }

    function writeStakeManagerContractAddress(address value) internal {
        writeStakeManagerContractAddress(storageTarget, value);
    }

    function writeDefaultValidatorAddress(address value) internal {
        writeDefaultValidatorAddress(storageTarget, value);
    }

    function writeWhitelistAddress(address value) internal {
        writeWhitelistAddress(storageTarget, value);
    }

    function writeDelegateRegistry(address value) internal {
        writeDelegateRegistry(storageTarget, value);
    }

    // --- SLOT 5–6: Uint256 Fields ---
    function readEpsilon() internal view returns (uint256) {
        return readEpsilon(storageTarget);
    }

    function readMinDeposit() internal view returns (uint256) {
        return readMinDeposit(storageTarget);
    }

    function writeEpsilon(uint256 value) internal {
        writeEpsilon(storageTarget, value);
    }

    function writeMinDeposit(uint256 value) internal {
        writeMinDeposit(storageTarget, value);
    }

    // --- SLOT 7: Validators Mapping ---
    function readValidator(address validator) internal view returns (Validator memory) {
        return readValidator(storageTarget, validator);
    }

    function writeValidator(address validatorKey, Validator memory v) internal {
        writeValidator(storageTarget, validatorKey, v);
    }

    function writeValidatorStakedAmount(address validatorKey, uint256 stakedAmount) internal {
        writeValidatorStakedAmount(storageTarget, validatorKey, stakedAmount);
    }

    function increaseValidatorStake(address validator, uint256 amount) public {
        Validator memory v = readValidator(validator);
        v.stakedAmount += amount;
        writeValidator(validator, v);
    }

    // --- SLOT 8: Validator Addresses Array ---
    function readValidatorAddressesLength() internal view returns (uint256) {
        return readValidatorAddressesLength(storageTarget);
    }

    function readValidatorAddressAt(uint256 index) internal view returns (address) {
        return readValidatorAddressAt(storageTarget, index);
    }

    function writeValidatorAddressesLength(uint256 length) internal {
        writeValidatorAddressesLength(storageTarget, length);
    }

    function writeValidatorAddressAt(uint256 index, address value) internal {
        writeValidatorAddressAt(storageTarget, index, value);
    }

    // --- SLOT 9: Withdrawals Mapping ---
    function readWithdrawal(address validator, uint256 nonce) internal view returns (Withdrawal memory) {
        return readWithdrawal(storageTarget, validator, nonce);
    }

    function writeWithdrawal(address validator, uint256 nonce, Withdrawal memory w) internal {
        writeWithdrawal(storageTarget, validator, nonce, w);
    }
}

abstract contract StorageUtils is TruStakePOLStorageUtils, ERC20StorageUtils {
// solhint-disable-previous-line no-empty-blocks
}
