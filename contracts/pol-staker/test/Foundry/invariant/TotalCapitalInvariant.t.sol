// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {console} from "forge-std/Test.sol";

import {StdUtils} from "forge-std/StdUtils.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseInvariantTest} from "./BaseTest.sol";
import {TruStakePOL} from "../../../contracts/main/TruStakePOL.sol";
import {Validator} from "../../../contracts/main/Types.sol";

/// An invariant test to check that the total capital matches the total shares value after deposits and withdrawals.
contract TotalCapitalInvariantTest is BaseInvariantTest {
    function setUp() public virtual override {
        BaseInvariantTest.setUp();

        // deploy and configure the handler
        DepositWithdrawHandler handler = new DepositWithdrawHandler(staker, IERC20(POL_TOKEN_ADDRESS));
        BaseInvariantTest.configHandler(address(handler));

        // initial deposit to allow to withdraw max-withdraw
        BaseInvariantTest.setupInitialDeposit();

        // call the external functions of the actor contract
        targetContract(address(handler));
    }

    function invariant_SharesValueMatchesCapital() public view {
        uint256 sharesSupply = staker.totalSupply();
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();

        uint256 sharesValue = sharesSupply * sharePriceNum / sharePriceDenom / 1e18;
        uint256 totalCapital = staker.totalAssets() + staker.totalStaked() + staker.totalRewards();

        assertEq(sharesValue, totalCapital);
    }
}

/// A handler to perfom random sequences of deposit, depositToSpecificValidator and withdraw calls.
/// It also simulates rewards by adding POL tokens to the staker.
contract DepositWithdrawHandler is StdUtils, StdCheats {
    uint256 constant wad = 1e18;

    TruStakePOL public staker;
    IERC20 public polToken;

    constructor(TruStakePOL _staker, IERC20 _polToken) {
        staker = _staker;
        polToken = _polToken;
    }

    function deposit(uint256 amount) external {
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

    function depositToSpecificValidator(uint256 amount, uint256 validatorIdx) external {
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
        console.log("depositToSpecificValidator: ", depositAmount, "validatorIdx: ", validator);
    }

    function withdrawFromSpecificValidator(uint256 amount, uint256 validatorIdx) external {
        // limit the withdraw amount between 0 and the user's max withdraw.
        uint256 maxWithdraw = staker.maxWithdraw(address(this));
        if (maxWithdraw == 0) return;

        // get the validator to withdraw from
        Validator[] memory validators = staker.getAllValidators();
        uint256 boundedIdx = bound(validatorIdx, 0, validators.length - 1);
        address validatorAddress = staker.validatorAddresses(boundedIdx);
        Validator memory selectedValidator = staker.validators(validatorAddress);

        // return if the validator has no stake
        uint256 stakedAmount = selectedValidator.stakedAmount;
        if (stakedAmount == 0) return;

        // limit the withdraw amount up to the user's max withdraw and the validator's staked amount
        uint256 maxWithdrawable = (maxWithdraw > stakedAmount) ? stakedAmount : maxWithdraw;
        uint256 withdrawAmount = bound(amount, 1, maxWithdrawable);

        // withdraw from the validator
        staker.withdrawFromSpecificValidator(withdrawAmount, validatorAddress);
        console.log("withdrawFromSpecificValidator: ", withdrawAmount, "validator: ", validatorAddress);
    }

    function simulateRewards(uint256 newAssets) external {
        (uint256 sharePriceNum, uint256 sharePriceDenom) = staker.sharePrice();
        uint256 totalCapital = staker.totalAssets() + staker.totalStaked() + staker.totalRewards();

        // increase staker assets up to 5%
        uint256 maxIncreasePerc = 5;
        uint256 assetIncrease = bound(newAssets, 0, totalCapital * maxIncreasePerc / 100);

        // add POL tokens to the staker to simulate staking rewards
        uint256 stakerBalance = polToken.balanceOf(address(staker));
        deal(address(polToken), address(staker), stakerBalance + assetIncrease, true);

        (sharePriceNum, sharePriceDenom) = staker.sharePrice();
    }
}
