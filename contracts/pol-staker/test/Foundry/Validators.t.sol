// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";
import {ITruStakePOL} from "../../contracts/interfaces/ITruStakePOL.sol";
import {Validator, ValidatorState} from "../../contracts/main/Types.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AddValidatorTests is BaseState {
    function testAddsValidator() public {
        // mock the call to the validatorShare contract
        address newValidatorAddress = makeAddr("NewValidator");

        // add the new validator
        staker.addValidator(newValidatorAddress);

        // check that the validator was added to the list of validator addresses
        address[] memory validators = staker.getValidators();
        address lastAddedAddress = validators[validators.length - 1];
        assertEq(lastAddedAddress, newValidatorAddress);

        // check that the validator was added to the validators mapping
        Validator memory v = staker.validators(newValidatorAddress);
        assertEq(v, Validator(ValidatorState.ENABLED, 0, address(0x0)));
    }

    function testEmitsEvent() public {
        address newValidatorAddress = address(0x9999);
        vm.expectEmit();
        emit ITruStakePOL.ValidatorAdded(newValidatorAddress);

        staker.addValidator(newValidatorAddress);
    }

    function testRevertsWithZeroAddress() public {
        vm.expectRevert(ITruStakePOL.ZeroAddressNotSupported.selector);

        staker.addValidator(address(0x0));
    }

    function testRevertsWithExistingAddress() public {
        vm.expectRevert(ITruStakePOL.ValidatorAlreadyExists.selector);

        staker.addValidator(defaultValidatorAddress);
    }

    function testRevertsWhenCallerIsNotTheOwner() public {
        address nonOwnerAddress = address(0x1234);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwnerAddress));
        vm.prank(nonOwnerAddress);

        staker.addValidator(address(0x9999));
    }
}

contract EnableValidatorTests is BaseState {
    function setUp() public override {
        super.setUp();
        staker.disableValidator(defaultValidatorAddress);
    }

    function testEnablesValidator() public {
        staker.enableValidator(defaultValidatorAddress);

        Validator memory v = staker.validators(defaultValidatorAddress);
        assertEq(uint8(v.state), uint8(ValidatorState.ENABLED));
    }

    function testEmitsEvent() public {
        vm.expectEmit();
        emit ITruStakePOL.ValidatorStateChanged(
            defaultValidatorAddress, ValidatorState.DISABLED, ValidatorState.ENABLED
        );

        staker.enableValidator(defaultValidatorAddress);
    }

    function testRevertsWithZeroAddress() public {
        vm.expectRevert(ITruStakePOL.ZeroAddressNotSupported.selector);

        staker.enableValidator(address(0x0));
    }

    function testRevertsWithUnknownValidatorAddress() public {
        vm.expectRevert(ITruStakePOL.ValidatorDoesNotExist.selector);

        address unknownValidatorAddress = address(0x7777);
        staker.enableValidator(unknownValidatorAddress);
    }

    function testRevertsWithEnabledValidatorAddress() public {
        staker.enableValidator(defaultValidatorAddress);

        vm.expectRevert(ITruStakePOL.ValidatorNotDisabled.selector);
        staker.enableValidator(defaultValidatorAddress);
    }

    function testRevertsWhenCallerIsNotTheOwner() public {
        address nonOwnerAddress = address(0x1234);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwnerAddress));
        vm.prank(nonOwnerAddress);

        staker.enableValidator(defaultValidatorAddress);
    }
}

contract DisableValidatorTests is BaseState {
    function testDisablesValidator() public {
        staker.disableValidator(defaultValidatorAddress);

        Validator memory v = staker.validators(defaultValidatorAddress);
        assertEq(uint8(v.state), uint8(ValidatorState.DISABLED));
    }

    function testEmitsEvent() public {
        vm.expectEmit();
        emit ITruStakePOL.ValidatorStateChanged(
            defaultValidatorAddress, ValidatorState.ENABLED, ValidatorState.DISABLED
        );

        staker.disableValidator(defaultValidatorAddress);
    }

    function testRevertsWithZeroAddress() public {
        vm.expectRevert(ITruStakePOL.ZeroAddressNotSupported.selector);

        staker.disableValidator(address(0x0));
    }

    function testRevertsWithUnknownValidatorAddress() public {
        vm.expectRevert(ITruStakePOL.ValidatorDoesNotExist.selector);

        address unknownValidatorAddress = address(0x7777);
        staker.disableValidator(unknownValidatorAddress);
    }

    function testRevertsWithDisabledValidatorAddress() public {
        staker.disableValidator(defaultValidatorAddress);

        vm.expectRevert(ITruStakePOL.ValidatorNotEnabled.selector);
        staker.disableValidator(defaultValidatorAddress);
    }

    function testRevertsWhenCallerIsNotTheOwner() public {
        address nonOwnerAddress = address(0x1234);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwnerAddress));
        vm.prank(nonOwnerAddress);

        staker.disableValidator(defaultValidatorAddress);
    }
}

contract SetDefaultValidatorTests is BaseState {
    function testSetsTheDefaultValidator() public {
        address newValidatorAddress = address(0x9999);
        staker.addValidator(newValidatorAddress);

        staker.setDefaultValidator(newValidatorAddress);

        assertEq(staker.stakerInfo().defaultValidatorAddress, newValidatorAddress);
    }

    function testEmitsEvent() public {
        address newValidatorAddress = address(0x9999);
        staker.addValidator(newValidatorAddress);

        vm.expectEmit();
        emit ITruStakePOL.SetDefaultValidator(defaultValidatorAddress, newValidatorAddress);

        staker.setDefaultValidator(newValidatorAddress);
    }

    function testRevertsWhenCallerIsNotTheOwner() public {
        address nonOwnerAddress = address(0x1234);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwnerAddress));
        vm.prank(nonOwnerAddress);

        staker.setDefaultValidator(defaultValidatorAddress);
    }

    function testRevertsWithZeroAddress() public {
        vm.expectRevert(abi.encodeWithSignature("ZeroAddressNotSupported()"));

        staker.setDefaultValidator(address(0x0));
    }

    function testRevertsWithNonEnabledValidator() public {
        // add a new validator and then disable it
        address newValidatorAddress = address(0x9999);
        staker.addValidator(newValidatorAddress);
        staker.disableValidator(newValidatorAddress);

        vm.expectRevert(abi.encodeWithSignature("ValidatorNotEnabled()"));

        staker.setDefaultValidator(newValidatorAddress);
    }
}

contract GetAllValidatorsTests is BaseState {
    function testReturnsAllValidators() public {
        address secondValidatorAddress = makeAddr("secondValidator");
        staker.addValidator(secondValidatorAddress);

        address thirdValidatorAddress = makeAddr("thirdValidator");
        staker.addValidator(thirdValidatorAddress);

        staker.disableValidator(thirdValidatorAddress);

        Validator[] memory validators = staker.getAllValidators();

        assertEq(validators[0], Validator(ValidatorState.ENABLED, 0, defaultValidatorAddress));
        assertEq(validators[1], Validator(ValidatorState.ENABLED, 0, secondValidatorAddress));
        assertEq(validators[2], Validator(ValidatorState.DISABLED, 0, thirdValidatorAddress));
    }
}

contract GetValidatorsTests is BaseState {
    function testIncludesDefaultValidator() public view {
        address[] memory validators = staker.getValidators();
        assertEq(validators.length, 1);
        assertEq(validators[0], defaultValidatorAddress);
    }
}
