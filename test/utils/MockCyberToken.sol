// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockCyberToken is ERC20 {
    constructor() ERC20("CyberConnect", "CYBER") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
