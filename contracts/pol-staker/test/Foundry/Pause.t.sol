// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract Pause is BaseState {
    function setUp() public virtual override {
        super.setUp(); // BaseState functionality
        staker.addValidator(secondValidatorAddress);

        // whitelist alice
        mockIsUserWhitelisted(alice, true);
    }

    function testCannotDepositWhenContractPaused() public {
        staker.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(alice);
        staker.deposit(1e18);
    }

    function testCannotDepositToSpecificValidatorWhenContractPaused() public {
        staker.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(alice);
        staker.depositToSpecificValidator(1e18, secondValidatorAddress);
    }

    function testCannotClaimWithdrawWhenContractPaused() public {
        staker.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(alice);
        staker.withdraw(1e18);
    }

    function testCannotClaimWithdrawFromSpecificValidatorWhenContractPaused() public {
        staker.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(alice);
        staker.withdrawFromSpecificValidator(1e18, secondValidatorAddress);
    }

    function testCannotClaimWithdrawalWhenContractPaused() public {
        staker.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(alice);
        staker.withdrawClaim(0, secondValidatorAddress);
    }

    function testCannotWithdrawClaimListWhenContractPaused() public {
        staker.pause();

        uint256[] memory nonces = new uint256[](1);
        nonces[0] = 0;

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        vm.prank(alice);
        staker.claimList(nonces, secondValidatorAddress);
    }

    function testCannotCompoundingRewardsWhenContractPaused() public {
        staker.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        staker.compoundRewards(defaultValidatorAddress);
    }

    function testContractCanOnlyBePausedByOwner() public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(alice)));
        vm.prank(alice);
        staker.pause();
    }

    function testContractCanOnlyBeUnpausedByOwner() public {
        staker.pause();
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(alice)));
        vm.prank(alice);
        staker.unpause();
    }

    function testNormalFunctionalityResumesAfterUnpause() public {
        uint256 depositAmount = 1 * 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        staker.pause();
        assertEq(staker.paused(), true);
        vm.prank(alice);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        staker.deposit(depositAmount);

        staker.unpause();
        assertEq(staker.paused(), false);

        vm.prank(alice);
        staker.deposit(depositAmount);
    }
}
