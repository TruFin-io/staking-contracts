// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";
import {ITruStakePOL} from "../../contracts/interfaces/ITruStakePOL.sol";
import {Withdrawal} from "../../contracts/main/Types.sol";
import {Validator, ValidatorState} from "../../contracts/main/Types.sol";

contract WithdrawState is BaseState {
    uint256 public depositAmount = 123_000 * 1e18;
    uint256 public reserve = 1 * 1e18;

    // set up the contract with some POL tokens staked
    function setUp() public virtual override {
        BaseState.setUp();

        // whitelist alice and charlie
        mockIsUserWhitelisted(alice, true);
        mockIsUserWhitelisted(charlie, true);

        // don't whitelist bob
        mockIsUserWhitelisted(bob, false);

        // set 1 POL reserve staked in the contract and mock deposit
        increaseValidatorStake(defaultValidatorAddress, reserve);

        increaseValidatorStake(defaultValidatorAddress, depositAmount);
        writeTotalSupply(depositAmount + reserve);
        writeBalanceOf(alice, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));

        // whitelist user
        mockIsUserWhitelisted(alice, true);
    }
}

contract WithdrawTests is WithdrawState {
    function testCanWithdrawMaxAmountWhenSharePriceIsOne() public {
        // mock calls to validator and stake manager
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        // verify that the share price is 1
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        // get the max withdraw amount (inclusive of epsilon)
        uint256 maxWithdraw = staker.maxWithdraw(alice);

        // user can withdraw the max amount
        vm.startPrank(alice);
        staker.withdraw(maxWithdraw);
    }

    function testCannotWithdrawMoreThanMaxAmountWhenSharePriceIsOne() public {
        // mock calls to validator and stake manager
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        // verify that the share price is 1
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        // get the max withdraw amount (inclusive of epsilon)
        uint256 maxWithdraw = staker.maxWithdraw(alice);

        // user trying to withdraw more than max amount should revert
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.WithdrawalAmountTooLarge.selector));

        staker.withdraw(maxWithdraw + 1);
    }

    function testCanWithdrawMaxAmountWhenSharePriceIsGreaterThanOne() public {
        // increase the stake of the default validator to increase the share price
        increaseValidatorStake(defaultValidatorAddress, 10_000 * 1e18);

        // verify that the share price is > 1
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertGt(sharePriceNum / sharePriceDenom, 1e18);

        // mock calls to validator and stake manager required for withdraw
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        // get the max withdraw amount (inclusive of epsilon)
        uint256 maxWithdraw = staker.maxWithdraw(alice);

        // user can withdraw the max amount
        vm.startPrank(alice);
        staker.withdraw(maxWithdraw);
    }

    function testCannotWithdrawMoreThanMaxAmountWhenSharePriceIsGreaterThanOne() public {
        // increase the stake of the default validator to increase the share price
        increaseValidatorStake(defaultValidatorAddress, 10_000 * 1e18);

        // verify that the share price is > 1
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertGt(sharePriceNum / sharePriceDenom, 1e18);

        // mock calls to validator and stake manager required for withdraw
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        // get the max withdraw amount (inclusive of epsilon)
        uint256 maxWithdraw = staker.maxWithdraw(alice);

        // user trying to withdraw more than max amount should revert
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.WithdrawalAmountTooLarge.selector));

        staker.withdraw(maxWithdraw + 1);
    }

    function testPartialWithdraw() public {
        // mock calls to validator and stake manager
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);
        mockGetLiquidRewards(defaultValidatorAddress, 0);

        vm.expectEmit();
        emit ITruStakePOL.WithdrawalRequested(
            alice,
            depositAmount / 2,
            depositAmount / 2,
            depositAmount / 2,
            0,
            0,
            defaultValidatorAddress,
            0,
            3456,
            0,
            depositAmount / 2 + reserve,
            depositAmount / 2 + reserve,
            0
        );

        // user withdraws a partial amount
        vm.startPrank(alice);
        (uint256 sharesBurned, uint256 unbondNonce) = staker.withdraw(depositAmount / 2);

        assertEq(staker.totalStaked(), depositAmount / 2 + reserve);
        assertEq(staker.balanceOf(alice), depositAmount / 2);
        assertEq(sharesBurned, depositAmount / 2);
        assertEq(unbondNonce, 0);

        Withdrawal memory withdrawal = staker.withdrawals(defaultValidatorAddress, 0);
        assertEq(withdrawal.user, alice);
        assertEq(withdrawal.amount, depositAmount / 2);
    }

    function testFullWithdrawal() public {
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        // user withdraws full amount
        vm.startPrank(alice);
        staker.withdraw(depositAmount);

        uint256 epsilon = readEpsilon(storageTarget);

        assertEq(staker.totalStaked(), reserve - epsilon);
        assertEq(staker.balanceOf(alice), 0);

        Withdrawal memory withdrawal = staker.withdrawals(defaultValidatorAddress, 0);
        assertEq(withdrawal.user, alice);
        assertEq(withdrawal.amount, depositAmount + epsilon);
    }

    function testMultiplePartialWithdrawals() public {
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);
        uint256 firstWithdraw = 2 * 1e18;
        uint256 secondWithdraw = 5 * 1e18;

        vm.startPrank(alice);
        staker.withdraw(firstWithdraw);
        mockUnbondNonce(defaultValidatorAddress);
        staker.withdraw(secondWithdraw);

        assertEq(staker.totalStaked(), depositAmount + reserve - firstWithdraw - secondWithdraw);
        assertEq(staker.balanceOf(alice), depositAmount - firstWithdraw - secondWithdraw);

        Withdrawal memory withdrawalOne = staker.withdrawals(defaultValidatorAddress, 0);
        assertEq(withdrawalOne.user, alice);
        assertEq(withdrawalOne.amount, firstWithdraw);

        Withdrawal memory withdrawalTwo = staker.withdrawals(defaultValidatorAddress, 1);
        assertEq(withdrawalTwo.user, alice);
        assertEq(withdrawalTwo.amount, secondWithdraw);
    }

    function testWithdrawalWithRewards() public {
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);
        mockGetLiquidRewards(defaultValidatorAddress, 10 * 1e18);

        uint256 totalRewards = staker.totalRewards();
        uint256 totalStaked = staker.totalStaked();
        uint256 totalShares = staker.totalSupply();
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        uint256 withdrawAmt = 1e18;
        uint256 withdrawShares = staker.convertToShares(withdrawAmt);
        uint256 treasuryShares = (totalRewards * fee * 1e18 * sharePriceDenom) / (sharePriceNum * FEE_PRECISION);

        assertEq(totalRewards, 10 * 1e18);
        assertEq(staker.totalAssets(), 0);
        assertEq(totalStaked, depositAmount + reserve);
        assertEq(totalShares, depositAmount + reserve);
        assertEq(staker.balanceOf(alice), depositAmount);

        vm.startPrank(alice);
        staker.withdraw(withdrawAmt);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 10 * 1e18, address(staker));

        (uint256 postSharePriceNum, uint256 postSharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, postSharePriceNum / postSharePriceDenom);
        assertEq(staker.totalStaked(), totalStaked - withdrawAmt);
        assertEq(staker.totalSupply(), totalShares - withdrawShares + treasuryShares);
        assertEq(staker.balanceOf(alice), depositAmount - withdrawShares);
        assertEq(staker.balanceOf(treasuryAddress), treasuryShares);

        Withdrawal memory withdrawalOne = staker.withdrawals(defaultValidatorAddress, 0);
        assertEq(withdrawalOne.user, alice);
        assertEq(withdrawalOne.amount, withdrawAmt);
    }

    function testWithdrawZeroReverts() public {
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.WithdrawalRequestAmountCannotEqualZero.selector));
        vm.startPrank(alice);
        staker.withdraw(0);
    }

    function testWithdrawMoreThanDepositedReverts() public {
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.WithdrawalAmountTooLarge.selector));
        vm.startPrank(alice);
        staker.withdraw(depositAmount + 1e18);
    }

    function testWithdrawWhenNotWhitelistedReverts() public {
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.UserNotWhitelisted.selector));
        vm.startPrank(bob);
        staker.withdraw(1e18);
    }

    function testCanImmediatelyWithdraw() public {
        mockIsUserWhitelisted(bob, true);
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        vm.startPrank(bob);
        staker.deposit(depositAmount);
        staker.withdraw(depositAmount);
    }
}

contract WithdrawFromSpecificValidator is WithdrawState {
    function setUp() public override {
        WithdrawState.setUp();
        staker.addValidator(secondValidatorAddress);

        // add reserve and mock deposit
        increaseValidatorStake(secondValidatorAddress, reserve);
        increaseValidatorStake(secondValidatorAddress, depositAmount);

        writeBalanceOf(charlie, depositAmount);
        writeTotalSupply(staker.totalSupply() + reserve + depositAmount);
        mockGetLiquidRewards(secondValidatorAddress, 0);
    }

    function testPartialWithdraw() public {
        mockUnbondNonce(secondValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        vm.expectEmit();
        emit ITruStakePOL.WithdrawalRequested(
            charlie,
            depositAmount / 2,
            depositAmount / 2,
            depositAmount / 2,
            0,
            0,
            secondValidatorAddress,
            0,
            3456,
            0,
            depositAmount / 2 + depositAmount + reserve * 2,
            depositAmount / 2 + depositAmount + reserve * 2,
            0
        );

        // user withdraws a partial amount
        vm.prank(charlie);
        (uint256 sharesBurned, uint256 unbondNonce) =
            staker.withdrawFromSpecificValidator(depositAmount / 2, secondValidatorAddress);

        assertEq(staker.totalStaked(), depositAmount / 2 + depositAmount + reserve * 2);
        assertEq(staker.balanceOf(charlie), depositAmount / 2);
        assertEq(sharesBurned, depositAmount / 2);
        assertEq(unbondNonce, 0);

        Withdrawal memory withdrawal = staker.withdrawals(secondValidatorAddress, 0);
        assertEq(withdrawal.user, charlie);
        assertEq(withdrawal.amount, depositAmount / 2);
    }

    function testFullWithdrawal() public {
        mockUnbondNonce(secondValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        // user withdraws full amount
        vm.prank(charlie);
        staker.withdrawFromSpecificValidator(depositAmount, secondValidatorAddress);

        uint256 epsilon = readEpsilon(storageTarget);
        assertEq(staker.totalStaked(), 2 * reserve + depositAmount - epsilon);
        assertEq(staker.balanceOf(charlie), 0);

        Withdrawal memory withdrawal = staker.withdrawals(secondValidatorAddress, 0);
        assertEq(withdrawal.user, charlie);
        assertEq(withdrawal.amount, depositAmount + epsilon);
    }

    function testTreasuryOnlyMintedSharesForClaimedRewards() public {
        uint256 validatorRewards = 10 * 1e18;
        mockUnbondNonce(secondValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);
        mockGetLiquidRewards(defaultValidatorAddress, validatorRewards);
        mockGetLiquidRewards(secondValidatorAddress, validatorRewards);

        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        uint256 treasuryShares = (validatorRewards * fee * 1e18 * sharePriceDenom) / (sharePriceNum * FEE_PRECISION);

        vm.startPrank(alice);
        staker.withdrawFromSpecificValidator(1e18, secondValidatorAddress);
        mockGetLiquidRewards(secondValidatorAddress, 0);

        assertEq(staker.balanceOf(treasuryAddress), treasuryShares);

        // withdrawal to the same validator should now mint no shares
        staker.withdrawFromSpecificValidator(1e18, secondValidatorAddress);
        assertEq(staker.balanceOf(treasuryAddress), treasuryShares);
    }

    function testWithdrawFromNonExistentValidatorReverts() public {
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.ValidatorDoesNotExist.selector));
        vm.startPrank(alice);
        staker.withdrawFromSpecificValidator(1e18, address(0));
    }

    function testWithdrawWhenNotWhitelistedReverts() public {
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.UserNotWhitelisted.selector));
        vm.startPrank(bob);
        staker.withdrawFromSpecificValidator(1e18, secondValidatorAddress);
    }

    function testWithdrawalWithAmountAboveValidatorStakeReverts() public {
        // mock user deposits to both validators
        mockUserDeposit(alice, defaultValidatorAddress, depositAmount);
        mockUserDeposit(alice, secondValidatorAddress, depositAmount);

        // verify that alice max withdraw is greater than the amount staked on the second validator
        Validator memory secondValidator = readValidator(secondValidatorAddress);
        assertGt(staker.maxWithdraw(alice), secondValidator.stakedAmount);

        // a withdrawal for an amount greater than what is staked on the validator should fail
        uint256 withdrawAmount = secondValidator.stakedAmount + 1;
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.WithdrawalAmountAboveValidatorStake.selector));
        vm.startPrank(alice);
        staker.withdrawFromSpecificValidator(withdrawAmount, secondValidatorAddress);
    }
}
