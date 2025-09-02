// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract CalculationsTests is BaseState {
    function setUp() public virtual override {
        BaseState.setUp();
    }

    function testSharePriceCalculation() public {
        // --------------------------
        // Scenario:
        // --------------------------
        // - Protocol uses share-based accounting.
        // - Initial users: Alice and Bob deposit 10,000 POL → receive 10,000 shares.
        // - Total POL locked in staking: 10,000 POL
        // - Protocol has 500 POL in vault (liquid assets)
        // - New rewards of 200 POL arrive from validator
        // - Protocol charges a 5% fee on rewards → 190 POL goes to users
        //
        // Total assets for share price calc:
        // = 10,000 (staked) + 500 (assets) + 190 (rewards net of fee)
        // = 10,690 POL
        //
        // Since total shares are still 10,000, share price becomes:
        //   10,690 / 10,000 = 1.069 per share
        //
        // --------------------------

        // Mock values
        uint256 totalStaked = 10_000 * wad; // 10,000 POL staked
        uint256 totalAssets = 500 * wad; // 500 POL sitting in vault
        uint256 totalRewards = 200 * wad; // 200 POL in unclaimed rewards
        uint256 totalSupply = 10_000 * wad; // 10,000 shares (TruPOL minted)

        // Mock external calls
        mockBalanceOf(stakingTokenAddress, totalAssets, address(staker));
        mockGetLiquidRewards(defaultValidatorAddress, totalRewards); // sets totalRewards

        // Write mock values to storage
        writeTotalSupply(totalSupply);
        writeValidatorStakedAmount(defaultValidatorAddress, totalStaked);

        // Assert mock values
        assertEq(staker.totalRewards(), totalRewards);
        assertEq(staker.totalStaked(), totalStaked);
        assertEq(staker.totalAssets(), totalAssets);

        // Call sharePrice
        (uint256 actualNum, uint256 actualDenom) = staker.sharePrice();

        // --------------------------
        // Manual expected calculation:
        // --------------------------
        // totalCapitalWithRewards = (10_000 + 500 + 95% of 200) = 10_690 POL
        //
        // Share price = totalCapital / totalSupply
        //   = 10,690 / 10,000 = 1.069
        //
        // When multiplied by FEE_PRECISION (1e4) to preserve precision:
        //   Numerator: 10,690 * 1e18 * 1e4 = 10690000000000000000000
        //   Denominator: 10,000 * 1e18 * 1e4 = 10000000000000000000000
        //
        // This results in a share price of 1.069 (scaled)
        // --------------------------

        uint256 expectedNum = 10_690_000_000_000_000_000_000 * FEE_PRECISION * wad;
        uint256 expectedDenom = 10_000 * wad * FEE_PRECISION;

        assertEq(actualNum, expectedNum, "Numerator mismatch");
        assertEq(actualDenom, expectedDenom, "Denominator mismatch");
    }

    function testConvertToShares() public {
        // ----------------------------------
        // Scenario:
        // ----------------------------------
        // - 10,000 POL staked (vault has staked it with validator)
        // - 500 POL in vault (liquid assets)
        // - 200 POL in validator rewards
        // - Fee = 5% => 190 POL goes to users
        // - Total capital = 10,000 + 500 + 190 = 10,690 POL
        // - totalSupply = 10,000 TruPOL (vault shares)
        // - share price = 1.069 (scaled as 1e18 fraction)
        //
        // We are depositing 1,000 POL → we expect ~935 TruPOL shares back.
        //
        // ----------------------------------

        // Mock values
        uint256 totalStaked = 10_000 * wad; // 10,000 POL staked
        uint256 totalAssets = 500 * wad; // 500 POL sitting in vault
        uint256 totalRewards = 200 * wad; // 200 POL in unclaimed rewards
        uint256 totalSupply = 10_000 * wad; // 10,000 shares (TruPOL minted)

        // Mock external calls
        mockBalanceOf(stakingTokenAddress, totalAssets, address(staker));
        mockGetLiquidRewards(defaultValidatorAddress, totalRewards); // sets totalRewards

        // Write mock values to storage
        writeTotalSupply(totalSupply);
        writeValidatorStakedAmount(defaultValidatorAddress, totalStaked);

        uint256 depositAssets = 1000 * wad;

        // --- Call ---
        uint256 actualShares = staker.convertToShares(depositAssets);

        // --- Manual expected calculation ---
        uint256 expectedShares = 935_453_695_042_095_416_276; // 935.453695042095416276 TruPOL shares

        // --- Assertion ---
        assertEq(actualShares, expectedShares, "convertToShares mismatch");
    }

    function testConvertToAssets() public {
        // --------------------------
        // Scenario:
        // --------------------------
        // - Vault has 10,000 POL staked
        // - 500 POL in vault
        // - 200 POL pending from validator
        // - Fee = 5% → 190 POL goes to users
        // - Total capital = 10,000 + 500 + 190 = 10,690 POL
        // - totalSupply = 10,000 TruPOL (vault shares)
        // - Share price = 1.069
        // --------------------------

        uint256 totalStaked = 10_000 * wad;
        uint256 totalAssets = 500 * wad;
        uint256 totalRewards = 200 * wad;
        uint256 totalSupply = 10_000 * wad;
        uint16 _fee = 500; // 5%

        // --- Mock setup ---
        mockBalanceOf(stakingTokenAddress, totalAssets, address(staker));
        mockGetLiquidRewards(defaultValidatorAddress, totalRewards);
        writeTotalSupply(totalSupply);
        writeValidatorStakedAmount(defaultValidatorAddress, totalStaked);
        writeFee(_fee);

        // We want to convert 50 TruPOL to POL assets
        uint256 shares = 50 * wad;

        // --- Call ---
        uint256 actualAssets = staker.convertToAssets(shares);
        (uint256 priceNum, uint256 priceDenom) = staker.sharePrice();

        // --- Manual expected calculation ---
        // assets = (shares * priceNum) / (priceDenom * 1e18)
        uint256 expectedAssets = Math.mulDiv(shares, priceNum, priceDenom * 1e18, Math.Rounding.Floor);

        assertEq(actualAssets, expectedAssets, "convertToAssets mismatch");
    }
}
