// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

interface IMintableBurnable {
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
    function mint(address account, uint256 amount) external;
}
