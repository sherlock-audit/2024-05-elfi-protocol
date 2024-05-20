// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import "../utils/TransferUtils.sol";

/// @title Vault
/// @dev This contract manages token transfers with role-based access control.
contract Vault is AccessControl {
    /// @dev Error thrown when attempting to transfer to the contract itself.
    error AddressSelfNotSupported(address self);

    /// @dev Role identifier for the admin role.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @dev Grants `ADMIN_ROLE` to the account that deploys the contract.
    /// @param admin The address to be granted the admin role.
    constructor(address admin) {
        _grantRole(ADMIN_ROLE, admin);
    }

    /// @dev Transfers tokens from the contract to a specified address, Only callable by an account with the `ADMIN_ROLE`.
    /// @param token The address of the token to transfer.
    /// @param receiver The address to receive the tokens.
    /// @param amount The amount of tokens to transfer.
    /// @custom:throws AddressSelfNotSupported if `receiver` is the contract itself.
    function transferOut(address token, address receiver, uint256 amount) external onlyRole(ADMIN_ROLE) {
        if (receiver == address(this)) {
            revert AddressSelfNotSupported(receiver);
        }
        TransferUtils.transfer(token, receiver, amount);
    }

    /// @dev Grants the `ADMIN_ROLE` to a new account. Only callable by an account with the `ADMIN_ROLE`.
    /// @param newAdmin The address to be granted the admin role.
    function grantAdmin(address newAdmin) external onlyRole(ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, newAdmin);
    }

    /// @dev Revokes the `ADMIN_ROLE` from an account. Only callable by an account with the `ADMIN_ROLE`.
    /// @param admin The address to have the admin role revoked.
    function revokeAdmin(address admin) external onlyRole(ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, admin);
    }
}
