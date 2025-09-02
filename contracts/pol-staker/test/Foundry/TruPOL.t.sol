// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {BaseState} from "./BaseState.t.sol";

contract TruPOLTests is BaseState {
    function testGetName() public view {
        assertEq(staker.name(), "TruStake POL Vault Shares");
    }

    function testGetSymbol() public view {
        assertEq(staker.symbol(), "TruPOL");
    }
}
