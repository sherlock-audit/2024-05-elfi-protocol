// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Vault.sol";

/// @title LpVault
/// @dev This contract inherits from Vault and initializes with an admin address.
contract LpVault is Vault {
    /// @dev Initializes the contract by setting the admin address.
    /// @param _admin The address to be granted the admin role.
    constructor(address _admin) Vault(_admin) {}
}
