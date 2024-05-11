// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IWETH.sol";
import "../mock/MockToken.sol";

contract WETH is MockToken, IWETH {
    error WithdrawFailed(address account, uint256 amount);

    constructor() MockToken("Mock for WETH", 18) {}

    function deposit() external payable override {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external override {
        _burn(msg.sender, amount);
        (bool success, ) = msg.sender.call{ value: amount }("");
        if (!success) {
            revert WithdrawFailed(msg.sender, amount);
        }
    }
    
}
