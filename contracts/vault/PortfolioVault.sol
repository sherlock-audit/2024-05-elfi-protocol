// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Vault.sol";

/// @title PortfolioVault Contract
/// @dev This contract serves as a vault for portfolio management.
contract PortfolioVault is Vault {
    /// @notice Initializes the PortfolioVault with an admin role.
    /// @param _admin The address granted the admin role.
    constructor(address _admin) Vault(_admin) {}
}
