// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";
import {ITruStakePOL} from "../../contracts/interfaces/ITruStakePOL.sol";

contract RestakeState is BaseState {
    uint256 public depositAmount = 10_000 * 1e18;

    function setUp() public virtual override {
        super.setUp();

        mockIsUserWhitelisted(alice, true);

        // deposit to default validator
        mockBuyVoucherPOL(defaultValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));
        mockAllowance(stakingTokenAddress, address(staker), stakeManagerContractAddress, depositAmount);

        vm.prank(alice);
        staker.deposit(depositAmount);
    }

    function testTreasuryMintedRewardsOnDepositIfRestakingFails() public {
        // add second validator and mock deposit
        staker.addValidator(secondValidatorAddress);
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        vm.prank(alice);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);

        uint256 treasuryPreBalance = staker.balanceOf(treasuryAddress);
        uint256 preBalance = staker.totalSupply();
        uint256 amountRestaked = 1_000 * 1e18;
        uint256 secondValidatorRewards = 1_000 * 1e18;
        uint256 assetsInStaker = 1_000 * 1e18;

        mockGetLiquidRewards(secondValidatorAddress, secondValidatorRewards);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockRestakePOL(defaultValidatorAddress, amountRestaked, amountRestaked);
        mockRestakePOL(secondValidatorAddress, 0, 0); // mock failed restake
        mockBalanceOf(stakingTokenAddress, assetsInStaker, address(staker)); // mock 1 POL assets in staker
        mockBuyVoucherPOL(secondValidatorAddress, assetsInStaker, assetsInStaker);

        (uint256 compoundSharePriceNum, uint256 compoundSharePriceDenom) = staker.sharePrice(); // share price during compound rewards
        uint256 sharesMintedForRestake =
            (amountRestaked) * uint256(fee) * 1e18 * compoundSharePriceDenom / (compoundSharePriceNum * FEE_PRECISION);

        staker.compoundRewards(secondValidatorAddress);

        uint256 midCompoundSharePriceNum = (
            (depositAmount * 2 + amountRestaked + secondValidatorRewards) * FEE_PRECISION
                + (FEE_PRECISION - uint256(fee)) * assetsInStaker
        ) * 1e18;
        uint256 midCompoundSharePriceDenom = (preBalance + sharesMintedForRestake) * FEE_PRECISION;
        uint256 sharesMintedForDeposit = assetsInStaker * uint256(fee) * 1e18 * midCompoundSharePriceDenom
            / (midCompoundSharePriceNum * FEE_PRECISION);

        uint256 treasuryPostBalance = staker.balanceOf(treasuryAddress);
        assertEq(treasuryPostBalance, treasuryPreBalance + sharesMintedForRestake + sharesMintedForDeposit);
    }

    function testTreasuryOnlyMintedSharesForSuccessfulRestakes() public {
        staker.addValidator(secondValidatorAddress);
        mockBuyVoucherPOL(secondValidatorAddress, depositAmount, depositAmount);
        mockGetLiquidRewards(secondValidatorAddress, 0);
        vm.prank(alice);
        staker.depositToSpecificValidator(depositAmount, secondValidatorAddress);

        uint256 treasuryPreBalance = staker.balanceOf(treasuryAddress);
        uint256 validatorRewards = 1_000 * 1e18;
        uint256 amountRestaked = 1_000 * 1e18;
        uint256 assetsInStaker = 1_000 * 1e18;

        mockGetLiquidRewards(secondValidatorAddress, validatorRewards);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockRestakePOL(defaultValidatorAddress, amountRestaked, amountRestaked);
        mockRestakePOL(secondValidatorAddress, 0, 0); // mock failed restake
        mockBalanceOf(stakingTokenAddress, assetsInStaker, address(staker));
        mockBuyVoucherPOL(defaultValidatorAddress, assetsInStaker, assetsInStaker);

        (uint256 compoundSharePriceNum, uint256 compoundSharePriceDenom) = staker.sharePrice(); // share price during compound rewards
        uint256 sharesMintedForRestake =
            (amountRestaked) * uint256(fee) * 1e18 * compoundSharePriceDenom / (compoundSharePriceNum * FEE_PRECISION);

        staker.compoundRewards(defaultValidatorAddress);

        uint256 treasuryPostBalance = staker.balanceOf(treasuryAddress);
        assertEq(treasuryPostBalance, treasuryPreBalance + sharesMintedForRestake);
    }

    function testCompoundRewardsEmitsEvent() public {
        uint256 amountRestaked = 1_000 * 1e18;
        uint256 assetsInStaker = 1_000 * 1e18;

        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockRestakePOL(defaultValidatorAddress, amountRestaked, amountRestaked);
        mockBalanceOf(stakingTokenAddress, assetsInStaker, address(staker));
        mockBuyVoucherPOL(defaultValidatorAddress, assetsInStaker, assetsInStaker);

        (uint256 compoundSharePriceNum, uint256 compoundSharePriceDenom) = staker.sharePrice(); // share price during compound rewards
        uint256 sharesMintedForRestake =
            (amountRestaked) * uint256(fee) * 1e18 * compoundSharePriceDenom / (compoundSharePriceNum * FEE_PRECISION);

        vm.expectEmit(true, true, true, true);
        emit ITruStakePOL.RewardsCompounded(
            amountRestaked,
            sharesMintedForRestake,
            sharesMintedForRestake,
            depositAmount + amountRestaked + assetsInStaker,
            depositAmount + sharesMintedForRestake,
            0,
            assetsInStaker
        );
        staker.compoundRewards(defaultValidatorAddress);
    }

    function testCompoundRewardsEmitsEventForError() public {
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockRestakePOLError(defaultValidatorAddress);
        mockBalanceOf(stakingTokenAddress, 0, address(staker));

        vm.expectEmit(true, true, true, true);
        emit ITruStakePOL.RestakeError(defaultValidatorAddress, "Restake error");
        staker.compoundRewards(defaultValidatorAddress);
    }

    function testCompoundRewardsWithDisabledStakerReverts() public {
        mockGetLiquidRewards(secondValidatorAddress, 0);
        mockGetLiquidRewards(defaultValidatorAddress, 0);
        mockRestakePOL(defaultValidatorAddress, 0, 0);
        mockRestakePOL(secondValidatorAddress, 0, 0);
        mockBalanceOf(stakingTokenAddress, wad, address(staker));

        staker.disableValidator(defaultValidatorAddress);
        vm.expectRevert(ITruStakePOL.ValidatorNotEnabled.selector);
        staker.compoundRewards(defaultValidatorAddress);
    }
}
