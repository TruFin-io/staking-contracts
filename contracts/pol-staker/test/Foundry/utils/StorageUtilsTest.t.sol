// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

import {BaseState} from "../BaseState.t.sol";

contract StorageUtilsTest is BaseState {
    function setUp() public override {
        BaseState.setUp();
    }

    function testTreasuryAddress() public {
        address expectedAddress = makeAddr("Treasury");
        assertEq(readTreasuryAddress(), expectedAddress);
    }

    function testFee() public view {
        uint16 expectedFee = 500;
        assertEq(readFee(), expectedFee);
    }

    // ERC20
    function testTotalSupply() public {
        uint256 expectedTotalSupply = staker.totalSupply();
        uint256 actualTotalSupply = readTotalSupply();
        assertEq(actualTotalSupply, expectedTotalSupply);
    }

    function testFuzzBalanceOf(address account, uint256 amount) public {
        vm.assume(account != address(0));
        bound(amount, 0, 2 ** 256 - 1);

        writeBalanceOf(account, amount);

        uint256 expectedBalance = staker.balanceOf(account);
        uint256 actualBalance = readBalanceOf(account);
        assertEq(actualBalance, expectedBalance);
    }
}
