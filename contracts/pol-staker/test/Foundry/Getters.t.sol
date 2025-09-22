// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";

contract MaxWithdrawTests is BaseState {
    function testInitialMaxWithdrawValue() public view {
        assertEq(staker.maxWithdraw(alice), 0);
    }

    function testMaxWithdrawAfterDeposit() public {
        uint256 depositAmount = 10_000_000 * 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        // whitelist alice
        mockIsUserWhitelisted(alice, true);

        // user deposits
        vm.startPrank(alice);
        staker.deposit(depositAmount);

        // verify max withdraw after deposit
        assertEq(staker.maxWithdraw(alice), depositAmount);
    }

    function testMaxWithdrawWithRounding() public {
        // whitelist alice
        mockIsUserWhitelisted(alice, true);

        // mock share price value to 1.096813197226058417
        uint256 sharePriceNum = 1821113913606475990877759022500;
        uint256 sharePriceDenom = 1660368345505178809970772240000;
        mockSetSharePrice(sharePriceNum, sharePriceDenom);

        // Alice initial TruPOL and max withdraw is 0
        assertEq(staker.balanceOf(alice), 0);
        assertEq(staker.maxWithdraw(alice), 0);

        // Alice deposits 1 million POL
        uint256 depositAmount = 1_000_000 * 1e18;
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.startPrank(alice);
        staker.deposit(depositAmount);

        // verify Alice's max withdraw is 1 wei less than 1 million POL due to rounding
        uint256 expectedMaxWithdraw = 999_999_999999999999999999;
        assertEq(staker.maxWithdraw(alice), expectedMaxWithdraw);
    }

    function testPreviewFunctionCircularChecks() public {
        // set up user with some TruPOL balance
        writeBalanceOf(alice, 10_000 * 1e18);

        // the amount of TruPOL tokens to check
        uint256 shareAmt = 1234 * 1e18;

        // initial share price is 1.0
        uint256 sharePriceNum = 1e18;
        uint256 sharePriceDenom = 1e18;

        for (uint256 i = 0; i < 10; i++) {
            uint256 polAmt = staker.previewRedeem(shareAmt);
            uint256 newShareAmt = staker.previewWithdraw(polAmt);

            // verify that share amount is the same as
            // the preview withdraw for the equivalent POL amount
            assertEq(shareAmt, newShareAmt, "Preview withdraw/redeem should match");

            // increase share price by an arbitrary amount for the next iteration
            sharePriceNum += (5678901234567890123 * i);
            sharePriceDenom += (3456701234567890123 * i);
            mockSetSharePrice(sharePriceNum, sharePriceDenom);
        }
    }

    function testGetDustReturnsCorrectValue() public {
        uint256 rewards = 1e18;
        mockGetLiquidRewards(defaultValidatorAddress, rewards);

        uint256 expectedDust = rewards * fee / FEE_PRECISION;
        uint256 actualDust = staker.getDust();
        assertEq(actualDust, expectedDust, "Dust value should be equal to expected value");
    }

    function testGetUnbondNonce() public {
        mockUnbondNonce(defaultValidatorAddress);

        uint256 actualUnbondNonce = staker.getUnbondNonce(defaultValidatorAddress);
        assertEq(actualUnbondNonce, 0, "Unbond nonce should be equal to 0");
    }
}
