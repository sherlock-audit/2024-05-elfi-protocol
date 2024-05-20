// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Vault.sol";

/// @title StakeToken Contract
/// @dev This contract allows for the minting and burning of stake tokens
contract StakeToken is ERC20, Vault {
    uint8 tokenDecimals = 18;

    /// @dev Initializes the contract with token name, symbol, decimals, and admin role.
    /// @param symbol_ The symbol of the stake token.
    /// @param _decimals The decimals of the stake token.
    /// @param _admin The address granted the admin role.
    constructor(string memory symbol_, uint8 _decimals, address _admin) ERC20("Stake token", symbol_) Vault(_admin) {
        tokenDecimals = _decimals;
    }

    /// @dev Mints stake tokens to a specified account. Can only be called by an account with the ADMIN_ROLE.
    /// @param account The account to mint tokens to.
    /// @param amount The amount of tokens to mint.
    function mint(address account, uint256 amount) external onlyRole(ADMIN_ROLE) {
        _mint(account, amount);
    }

    /// @dev Burns stake tokens from a specified account. Can only be called by an account with the ADMIN_ROLE.
    /// @param account The account to burn tokens from.
    /// @param amount The amount of tokens to burn.
    function burn(address account, uint256 amount) external onlyRole(ADMIN_ROLE) {
        _burn(account, amount);
    }

    /// @dev Returns the number of decimals
    /// @return The number of decimals for the stake tokens.
    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }
}
