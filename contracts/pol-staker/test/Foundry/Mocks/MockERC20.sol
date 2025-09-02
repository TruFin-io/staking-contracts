// SPDX-License-Identifier: GPL-3.0
pragma solidity =0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Polygon", "POL") {
        _mint(msg.sender, 100000e18);
    }
}
