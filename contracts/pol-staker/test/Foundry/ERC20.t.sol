// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract ERC20 is BaseState {
    uint256 public depositAmount = 10_000 * 1e18;

    function setUp() public override {
        BaseState.setUp();
        mockIsUserWhitelisted(alice, true);
        mockIsUserWhitelisted(charlie, true);
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.prank(alice);
        staker.deposit(depositAmount);
    }

    function testTotalSupplyNotAlteredByRewards() public {
        uint256 totalSupply = staker.totalSupply();
        mockGetLiquidRewards(defaultValidatorAddress, 1e18);
        assertEq(totalSupply, staker.totalSupply());
    }

    function testTotalSupplyAlteredByRewardsAfterDeposit() public {
        uint256 rewards = 1e18;
        uint256 totalSupply = staker.totalSupply();
        mockGetLiquidRewards(defaultValidatorAddress, rewards);
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();

        uint256 sharesMinted = staker.convertToShares(depositAmount);
        uint256 treasurySharesMinted = (rewards * fee * 1e18 * sharePriceDenom) / (sharePriceNum * FEE_PRECISION);

        vm.prank(alice);
        staker.deposit(depositAmount);

        assertEq(staker.totalSupply(), totalSupply + treasurySharesMinted + sharesMinted);
    }

    function testWithdrawRequestPreAccrualDecreasesTotalSupply() public {
        uint256 totalSupply = staker.totalSupply();
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        vm.prank(alice);
        staker.withdraw(1e18);
        assertEq(staker.totalSupply(), totalSupply - 1e18);
        assertEq(staker.balanceOf(alice), depositAmount - 1e18);
    }

    function testWithdrawRequestPostAccrualDecreasesTotalSupply() public {
        uint256 rewards = 1e18;
        mockGetLiquidRewards(defaultValidatorAddress, rewards);
        mockUnbondNonce(defaultValidatorAddress);
        mockGetEpoch(3456, stakeManagerContractAddress);

        uint256 totalSupply = staker.totalSupply();
        uint256 withdrawAmount = 1e18;
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        uint256 sharesBurned = (withdrawAmount * sharePriceDenom * 1e18) / sharePriceNum;
        uint256 treasurySharesMinted = (rewards * fee * 1e18 * sharePriceDenom) / (sharePriceNum * FEE_PRECISION);

        vm.prank(alice);
        staker.withdraw(1e18);
        assertEq(staker.totalSupply(), totalSupply - sharesBurned + treasurySharesMinted);
        assertEq(staker.balanceOf(alice), depositAmount - sharesBurned);
    }

    function testBalanceOfPostRewardAccrual() public {
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        assertEq(sharePriceNum / sharePriceDenom, 1e18);

        uint256 rewards = 1e18;
        mockGetLiquidRewards(defaultValidatorAddress, rewards);

        (sharePriceNum, sharePriceDenom) = staker.sharePrice();
        uint256 postSharePriceNum = ((depositAmount + 0) * FEE_PRECISION + (FEE_PRECISION - fee) * rewards) * 1e18;
        uint256 postSharePriceDenom = staker.totalSupply() * FEE_PRECISION;

        assertEq(sharePriceNum / sharePriceDenom, postSharePriceNum / postSharePriceDenom);
    }

    function testTransferPostDeposit() public {
        assertEq(staker.balanceOf(charlie), 0);
        assertEq(staker.balanceOf(alice), depositAmount);

        vm.prank(alice);
        staker.transfer(charlie, depositAmount / 2);

        assertEq(staker.balanceOf(charlie), depositAmount / 2);
        assertEq(staker.balanceOf(alice), depositAmount / 2);
    }

    function testTransferMoreThanBalanceReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, alice, depositAmount, depositAmount * 2
            )
        );
        vm.prank(alice);
        staker.transfer(charlie, depositAmount * 2);
    }

    function testTransferFrom() public {
        assertEq(staker.balanceOf(charlie), 0);
        assertEq(staker.balanceOf(alice), depositAmount);

        vm.startPrank(charlie);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, charlie, 0, depositAmount / 2)
        );
        staker.transferFrom(alice, charlie, depositAmount / 2);

        staker.approve(alice, depositAmount / 2);

        resetPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, charlie, 0, depositAmount / 2)
        );
        staker.transferFrom(charlie, alice, depositAmount / 2);
    }

    function testTransferFromPostDeposit() public {
        vm.startPrank(alice);
        staker.approve(charlie, depositAmount);

        resetPrank(charlie);
        staker.transferFrom(alice, charlie, depositAmount / 2);

        assertEq(readAllowance(alice, charlie), depositAmount / 2);
        assertEq(staker.balanceOf(charlie), depositAmount / 2);
        assertEq(staker.balanceOf(alice), depositAmount / 2);
    }
}
