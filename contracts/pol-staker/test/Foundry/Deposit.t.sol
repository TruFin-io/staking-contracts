// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ITruStakePOL} from "../../contracts/interfaces/ITruStakePOL.sol";
import {Validator, ValidatorState} from "../../contracts/main/Types.sol";
import {MockERC20} from "./Mocks/MockERC20.sol";

contract DepositState is BaseState {
    function setUp() public virtual override {
        super.setUp(); // BaseState functionality
        staker.addValidator(secondValidatorAddress);

        // whitelist alice and charlie
        mockIsUserWhitelisted(alice, true);
        mockIsUserWhitelisted(charlie, true);
        // don't whitelist bob
        mockIsUserWhitelisted(bob, false);
    }
}

contract DepositTests is DepositState {
    MockERC20 public stakingToken = new MockERC20();

    function testSingleDeposit() public {
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.prank(alice);
        uint256 sharesMinted = staker.deposit(depositAmount);

        assertEq(sharesMinted, depositAmount);
        assertEq(staker.totalStaked(), depositAmount);
        assertEq(staker.totalSupply(), depositAmount);
        assertEq(staker.totalRewards(), 0);
        assertEq(staker.totalAssets(), 0);

        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        assertEq(staker.balanceOf(alice), depositAmount);
    }

    function testDepositEmitsEvent() public {
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.expectEmit();
        emit ITruStakePOL.Deposited(
            alice,
            depositAmount,
            depositAmount,
            depositAmount,
            depositAmount,
            0,
            0,
            defaultValidatorAddress,
            0,
            depositAmount,
            depositAmount,
            0
        );

        vm.prank(alice);
        staker.deposit(depositAmount);
    }

    function testDepositUpdatesUserInfo() public {
        mockGetEpoch(123, stakeManagerContractAddress);
        (
            uint256 maxRedeemable,
            uint256 maxWithdrawAmount,
            uint256 globalPriceNum,
            uint256 globalPriceDenom,
            uint256 epoch
        ) = staker.getUserInfo(alice);

        assertEq(maxRedeemable, 0);
        assertEq(maxWithdrawAmount, 0);
        assertEq(globalPriceNum, 1e18);
        assertEq(globalPriceDenom, 1);
        assertEq(epoch, 123);

        // deposit
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);
        vm.prank(alice);
        staker.deposit(depositAmount);

        (maxRedeemable, maxWithdrawAmount, globalPriceNum, globalPriceDenom, epoch) = staker.getUserInfo(alice);

        assertEq(maxRedeemable, depositAmount);
        assertEq(maxWithdrawAmount, depositAmount + staker.stakerInfo().epsilon);
        assertEq(globalPriceNum, depositAmount * SHARE_PRICE_PRECISION);
        assertEq(globalPriceDenom, depositAmount * FEE_PRECISION);
        assertEq(epoch, 123);
    }

    function testDepositWithTooLittlePOLFails() public {
        writeStakingTokenAddress(address(stakingToken));

        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);

        vm.startPrank(alice);
        IERC20(address(stakingToken)).approve(address(staker), depositAmount);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, depositAmount));
        staker.deposit(depositAmount);
    }

    function testMultipleDeposits() public {
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.startPrank(alice);
        staker.deposit(depositAmount);
        staker.deposit(depositAmount);

        assertEq(staker.totalStaked(), 2 * depositAmount);
        assertEq(staker.totalSupply(), 2 * depositAmount);
        assertEq(staker.totalRewards(), 0);
        assertEq(staker.totalAssets(), 0);

        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        assertEq(staker.balanceOf(alice), 2 * depositAmount);
    }

    function testDepositsByMultipleUsers() public {
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.startPrank(alice);
        staker.deposit(depositAmount);
        staker.deposit(depositAmount);

        resetPrank(charlie);
        staker.deposit(depositAmount);

        assertEq(staker.totalStaked(), 3 * depositAmount);
        assertEq(staker.totalSupply(), 3 * depositAmount);
        assertEq(staker.totalRewards(), 0);
        assertEq(staker.totalAssets(), 0);

        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        assertEq(staker.balanceOf(alice), 2 * depositAmount);
        assertEq(staker.balanceOf(charlie), depositAmount);
    }

    function testRevertsWhenDepositingZeroPOL() public {
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.DepositBelowMinDeposit.selector));

        vm.prank(alice);
        staker.deposit(0);
    }

    function testRevertsWithLessThanMinDepositAmount() public {
        uint256 depositAmount = 1e18 - 1;
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(secondValidatorAddress, 0);

        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.DepositBelowMinDeposit.selector));

        // user tries to deposit less than min-deposit
        vm.prank(alice);
        staker.deposit(depositAmount);
    }

    function testRevertsWithNonWhitelistedUser() public {
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.UserNotWhitelisted.selector));
        // non-whitelisted user tries to deposit
        vm.prank(bob);
        staker.deposit(1e18);
    }

    function testCanDepositMinDepositAmount() public {
        uint256 minDeposit = 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, minDeposit, minDeposit);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, minDeposit);

        staker.setMinDeposit(minDeposit);

        // user deposits min-deposit to default validator
        vm.prank(alice);
        staker.deposit(minDeposit);

        // check amount staked on validator
        Validator memory defaultValidator = staker.validators(defaultValidatorAddress);
        assertEq(defaultValidator.stakedAmount, minDeposit);
    }

    function testDepositUpdatesValidatorStruct() public {
        uint256 depositAmount = 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.prank(alice);
        staker.deposit(depositAmount);

        // check amount staked on validator
        Validator memory defaultValidator = staker.getAllValidators()[0];
        assertEq(defaultValidator, Validator(ValidatorState.ENABLED, depositAmount, defaultValidatorAddress));
    }

    function testInflationAttackDoesNotWork() public {
        uint256 initialValue = 1e18;
        uint256 attackValue = 10000 * wad;
        uint256 depositValue = 10000 * wad;

        mockBuyVoucherPOL(defaultValidatorAddress, initialValue, initialValue);
        mockBuyVoucherPOL(defaultValidatorAddress, depositValue + attackValue, depositValue + attackValue);
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, initialValue);
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositValue);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);

        vm.startPrank(alice);
        staker.deposit(initialValue);

        resetPrank(charlie);
        mockBalanceOf(stakingTokenAddress, attackValue, address(staker));
        staker.deposit(depositValue);

        assertEq(staker.balanceOf(alice), initialValue);
        // The victim didn't receive zero shares
        assertGt(staker.balanceOf(charlie), 0);
    }
}

contract DepositToSpecificValidatorTests is DepositState {
    function testSingleDeposit() public {
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        // user deposits to specific validator
        vm.startPrank(alice);
        uint256 sharesMinted = staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);

        assertEq(sharesMinted, depositAmount);
        assertEq(staker.totalStaked(), depositAmount);
        assertEq(staker.totalSupply(), depositAmount);
        assertEq(staker.totalRewards(), 0);
        assertEq(staker.totalAssets(), 0);

        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        assertEq(staker.balanceOf(alice), depositAmount);
    }

    function testIncreasesValidatorStake() public {
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        // user deposits to specific validator
        vm.startPrank(alice);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);

        // check amount staked on specific validator
        Validator memory secondValidator = staker.validators(secondValidatorAddress);
        assertEq(secondValidator.stakedAmount, depositAmount);

        // check default validator didn't increase staked amount
        Validator memory defaultValidator = staker.validators(defaultValidatorAddress);
        assertEq(defaultValidator.stakedAmount, 0);
    }

    function testCanDepositMinDepositAmount() public {
        uint256 minDeposit = 1e18;
        mockBuyVoucherPOL(secondValidatorAddress, minDeposit, minDeposit);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, minDeposit);

        staker.setMinDeposit(minDeposit);

        // user deposits min-deposit to specific validator
        vm.prank(alice);
        staker.depositToSpecificValidator(minDeposit, secondValidatorAddress);

        // check amount staked on validator
        Validator memory secondValidator = staker.validators(secondValidatorAddress);
        assertEq(secondValidator.stakedAmount, minDeposit);
    }

    function testMultipleDeposits() public {
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.startPrank(alice);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);

        assertEq(staker.totalStaked(), 2 * depositAmount);
        assertEq(staker.totalSupply(), 2 * depositAmount);
        assertEq(staker.totalRewards(), 0);
        assertEq(staker.totalAssets(), 0);

        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        assertEq(staker.balanceOf(alice), 2 * depositAmount);
    }

    function testRevertsWithNonWhitelistedUser() public {
        uint256 depositAmount = 1e18;
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(secondValidatorAddress, 0);

        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.UserNotWhitelisted.selector));

        // non-whitelisted user tries to deposit to specific validator
        vm.prank(bob);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);
    }

    function testRevertsWithLessThanMinDepositAmount() public {
        uint256 depositAmount = 1e18 - 1;
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(secondValidatorAddress, 0);

        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.DepositBelowMinDeposit.selector));

        // user tries to deposit less than min-deposit to specific validator
        vm.prank(alice);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);
    }

    function testRevertsWhenStakingToNonExistentValidator() public {
        uint256 depositAmount = 1e18;

        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.ValidatorNotEnabled.selector));

        // user tries to deposit to non-existent validator
        vm.prank(alice);
        staker.depositToSpecificValidator(depositAmount, alice);
    }

    function testRevertsWhenStakingToADisabledValidator() public {
        uint256 depositAmount = 1e18;

        staker.disableValidator(secondValidatorAddress);

        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.ValidatorNotEnabled.selector));

        // user tries to deposit to disabled validator
        vm.prank(alice);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);
    }

    function testDepositsByMultipleUsers() public {
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.startPrank(alice);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);

        resetPrank(charlie);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);

        assertEq(staker.totalStaked(), 3 * depositAmount);
        assertEq(staker.totalSupply(), 3 * depositAmount);
        assertEq(staker.totalRewards(), 0);
        assertEq(staker.totalAssets(), 0);

        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        assertEq(staker.balanceOf(alice), 2 * depositAmount);
        assertEq(staker.balanceOf(charlie), depositAmount);
    }

    function testDepositsByMultipleUsersToDifferentValidators() public {
        uint256 depositAmount = 10_000 * 1e18;
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.startPrank(alice);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);
        staker.deposit(depositAmount);

        resetPrank(charlie);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);

        assertEq(staker.totalStaked(), 3 * depositAmount);
        assertEq(staker.totalSupply(), 3 * depositAmount);
        assertEq(staker.totalRewards(), 0);
        assertEq(staker.totalAssets(), 0);

        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        assertEq(staker.balanceOf(alice), 2 * depositAmount);
        assertEq(staker.balanceOf(charlie), depositAmount);
    }

    function testRevertsWhenDepositingZeroPOL() public {
        vm.expectRevert(abi.encodeWithSelector(ITruStakePOL.DepositBelowMinDeposit.selector));

        vm.prank(alice);
        staker.depositToSpecificValidator(0, secondValidatorAddress);
    }

    function testDepositMintsTreasurySharesForRewards() public {
        uint256 depositAmount = 1e18;
        uint256 defaultValidatorRewards = 1e18;

        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, 2 * depositAmount);

        vm.startPrank(alice);
        staker.deposit(depositAmount);

        // treasury should get minted shares for the rewards
        mockGetLiquidRewards(defaultValidatorAddress, defaultValidatorRewards);
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        staker.deposit(depositAmount);

        uint256 treasuryShares =
            (defaultValidatorRewards * fee * 1e18 * sharePriceDenom) / (sharePriceNum * FEE_PRECISION);

        assertEq(staker.balanceOf(treasuryAddress), treasuryShares);
    }
}
