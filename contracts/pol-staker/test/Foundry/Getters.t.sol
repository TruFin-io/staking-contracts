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
        uint256 epsilon = staker.stakerInfo().epsilon;
        assertEq(staker.maxWithdraw(alice), depositAmount + epsilon);
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

            // verify that the preview share amount is approximately
            // the same as the initial share amount
            assertApproxEqAbs(shareAmt, newShareAmt, 1);

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
