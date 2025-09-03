// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";
import {ITruStakePOL} from "../../contracts/interfaces/ITruStakePOL.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Withdrawal} from "../../contracts/main/Types.sol";

contract WithdrawClaimState is BaseState {
    function setUp() public virtual override {
        BaseState.setUp();

        // set 1 POL reserve staked in the contract
        uint256 reserve = 1 * 1e18;
        increaseValidatorStake(defaultValidatorAddress, reserve);

        // mock deposit
        uint256 depositAmount = 123_000 * 1e18;
        increaseValidatorStake(defaultValidatorAddress, depositAmount);
        writeTotalSupply(depositAmount + reserve);
        writeBalanceOf(alice, depositAmount);

        // whitelist user
        mockIsUserWhitelisted(alice, true);

        // withdraw
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(1, stakeManagerContractAddress);
        vm.prank(alice);
        staker.withdraw(1_000 * 1e18);
    }

    function testNoPOLReceivedByValidator() public {
        // ensure expected event is emitted
        vm.expectEmit(true, true, true, true);

        emit ITruStakePOL.WithdrawalClaimed(
            address(alice), // user address
            defaultValidatorAddress, // validator address
            0, // unbond nonce
            1_000 * 1e18, // amount claimed
            0 // amount transferred
        );

        // claim withdrawal
        uint256 preBalance = IERC20(stakingTokenAddress).balanceOf(address(staker));
        vm.prank(alice);
        staker.withdrawClaim(0, defaultValidatorAddress);
        uint256 postBalance = IERC20(stakingTokenAddress).balanceOf(address(staker));
        assertEq(preBalance, postBalance);
    }

    function testClaimWithdrawalFromDifferentUserReverts() public {
        mockIsUserWhitelisted(bob, true);

        vm.expectRevert(ITruStakePOL.SenderMustHaveInitiatedWithdrawalRequest.selector);
        vm.prank(bob);
        staker.withdrawClaim(0, defaultValidatorAddress);

        Withdrawal memory withdrawal = staker.withdrawals(defaultValidatorAddress, 0);
        assertEq(withdrawal.user, address(alice));
        assertEq(withdrawal.amount, 1_000 * 1e18);
    }

    function testClaimNonExistentWithdrawalReverts() public {
        vm.expectRevert(ITruStakePOL.WithdrawClaimNonExistent.selector);
        vm.prank(alice);
        staker.withdrawClaim(1, defaultValidatorAddress);
    }

    function testClaimWithdrawalTwiceReverts() public {
        vm.startPrank(alice);
        staker.withdrawClaim(0, defaultValidatorAddress);

        vm.expectRevert(ITruStakePOL.WithdrawClaimNonExistent.selector);
        staker.withdrawClaim(0, defaultValidatorAddress);
    }

    function testClaimWithdrawalWhenNotWhitelistedReverts() public {
        mockIsUserWhitelisted(bob, false);
        vm.prank(bob);
        vm.expectRevert(ITruStakePOL.UserNotWhitelisted.selector);
        staker.withdrawClaim(0, defaultValidatorAddress);
    }

    function testClaimListWhenNotWhitelistedReverts() public {
        mockIsUserWhitelisted(bob, false);

        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = 0;

        vm.prank(bob);
        vm.expectRevert(ITruStakePOL.UserNotWhitelisted.selector);
        staker.claimList(validatorIds, defaultValidatorAddress);
    }

    function testClaimListWithInvalidNoncesReverts() public {
        uint256[] memory validatorIds = new uint256[](1);
        validatorIds[0] = 8;

        vm.prank(alice);
        vm.expectRevert(ITruStakePOL.WithdrawClaimNonExistent.selector);
        staker.claimList(validatorIds, defaultValidatorAddress);
    }

    function testIsClaimableReturnsFalseForNonClaimableWithdrawal() public {
        mockGetEpoch(79, stakeManagerContractAddress);
        mockGetUnbonds(defaultValidatorAddress, 0, 80);
        mockWithdrawalDelay(stakeManagerContractAddress);

        assertEq(staker.isClaimable(0, defaultValidatorAddress), false, "Withdrawal should not be claimable");
    }

    function testIsClaimableReturnsFalseForNonExistentWithdrawal() public {
        mockGetEpoch(79, stakeManagerContractAddress);
        mockGetUnbonds(defaultValidatorAddress, 5, 80);
        mockWithdrawalDelay(stakeManagerContractAddress);

        assertEq(staker.isClaimable(5, defaultValidatorAddress), false, "Withdrawal should not be claimable");
    }

    function testIsClaimableReturnsTrueForClaimableWithdrawals() public {
        mockGetEpoch(81, stakeManagerContractAddress);
        mockGetUnbonds(defaultValidatorAddress, 0, 1);
        mockWithdrawalDelay(stakeManagerContractAddress);

        assertEq(staker.isClaimable(0, defaultValidatorAddress), true, "Withdrawal should be claimable");
    }
}
