// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Vault.sol";

contract StakeToken is ERC20, Vault {
    uint8 tokenDecimals = 18;

    constructor(string memory symbol_, uint8 _decimals, address _admin) ERC20("Stake token", symbol_) Vault(_admin) {
        tokenDecimals = _decimals;
    }

    function mint(address account, uint256 amount) external onlyRole(ADMIN_ROLE) {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyRole(ADMIN_ROLE) {
        _burn(account, amount);
    }

    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }
}
