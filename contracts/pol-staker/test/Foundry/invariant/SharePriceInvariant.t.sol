// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {console} from "forge-std/Test.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseInvariantTest} from "./BaseTest.sol";
import {TruStakePOL} from "../../../contracts/main/TruStakePOL.sol";

/// An invariant test to check that the share price does not change during deposits.
contract SharePriceInvariantTest is BaseInvariantTest {
    DepositHandler handler;

    function setUp() public virtual override {
        BaseInvariantTest.setUp();

        // deploy and configure the handler
        IERC20 polToken = IERC20(POL_TOKEN_ADDRESS);
        handler = new DepositHandler(staker, polToken);
        BaseInvariantTest.configHandler(address(handler));

        // initial deposit to allow to withdraw max-withdraw
        BaseInvariantTest.setupInitialDeposit();

        // call the external functions of the actor contract
        targetContract(address(handler));
    }

    function invariant_SharesPriceDoesNotChange() public view {
        // get the share price before and after the deposit
        (uint256 initialSharePriceNum, uint256 initialSharePriceDenom) = handler.initialSharePrice();
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();

        console.log(
            "invariant_SharesPriceDoesNotChange - initial share price: ",
            initialSharePriceNum / initialSharePriceDenom,
            "current share price: ",
            sharePriceNum / sharePriceDenom
        );

        assertApproxEqAbs(
            initialSharePriceNum / initialSharePriceDenom,
            sharePriceNum / sharePriceDenom,
            1, // max difference allowed
            "Share price changed during deposits"
        );
    }
}

/// A handler to perfom random sequences of deposit and depositToSpecificValidator calls.
contract DepositHandler is StdUtils, StdCheats {
    uint256 constant wad = 1e18;

    TruStakePOL public staker;
    IERC20 public polToken;

    uint256 sharePriceNum;
    uint256 sharePriceDenom;
    bool sharePriceIsSet;

    constructor(TruStakePOL _staker, IERC20 _polToken) {
        staker = _staker;
        polToken = _polToken;

        // set the initial share price
        (sharePriceNum, sharePriceDenom) = staker.sharePrice();
        console.log("initial share price: ", sharePriceNum / sharePriceDenom);
    }

    function initialSharePrice() external view returns (uint256, uint256) {
        return (sharePriceNum, sharePriceDenom);
    }

    function deposit(uint256 amount, uint256 newAssets) external {
        increaseSharePrice(newAssets);

        // limit the deposit amount between the min and the user's balance.
        uint256 minDeposit = staker.stakerInfo().minDeposit;
        uint256 maxDeposit = polToken.balanceOf(address(this));

        // return if can't deposit the min amount
        if (maxDeposit < minDeposit) return;

        uint256 depositAmount = bound(amount, minDeposit, maxDeposit);
        polToken.approve(address(staker), depositAmount);
        staker.deposit(depositAmount);

        console.log("deposit: ", depositAmount);
    }

    function depositToSpecificValidator(uint256 amount, uint256 validatorIdx, uint256 newAssets) external {
        increaseSharePrice(newAssets);

        // limit the deposit amount between the min and the user's balance.
        uint256 minDeposit = staker.stakerInfo().minDeposit;
        uint256 maxDeposit = polToken.balanceOf(address(this));

        // return if can't deposit the min amount
        if (maxDeposit < minDeposit) return;

        uint256 depositAmount = bound(amount, minDeposit, maxDeposit);

        // get validator to deposit into
        uint256 validator = bound(validatorIdx, 0, 3);
        address validatorAddress = staker.validatorAddresses(validator);

        polToken.approve(address(staker), depositAmount);
        staker.depositToSpecificValidator(depositAmount, validatorAddress);

        console.log("depositToSpecificValidator: ", depositAmount);
    }

    // Increases the new share price once per run.
    function increaseSharePrice(uint256 newAssets) private {
        if (sharePriceIsSet) {
            // if the share price is already set return to avoid changing it again during a run.
            return;
        }

        // set new share price
        simulateRewards(newAssets);
        (sharePriceNum, sharePriceDenom) = staker.sharePrice();
        sharePriceIsSet = true;
        console.log("increaseSharePrice - new share price set: ", sharePriceNum / sharePriceDenom);
    }

    // Simulates staking rewards by adding a random amount POL tokens to the staker.
    function simulateRewards(uint256 newAssets) private {
        uint256 totalCapital = staker.totalAssets() + staker.totalStaked() + staker.totalRewards();

        // increase staker assets up to 100%
        uint256 maxIncreasePerc = 100;
        uint256 assetIncrease = bound(newAssets, 0, totalCapital * maxIncreasePerc / 100);

        // add POL tokens to the staker to simulate staking rewards
        uint256 stakerBalance = polToken.balanceOf(address(staker));
        deal(address(polToken), address(staker), stakerBalance + assetIncrease, true);
    }
}
