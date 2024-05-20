// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IRoleAccessControl.sol";
import "../storage/RoleAccessControl.sol";

/// @title Role Access Control Facet
/// @dev This contract provides role-based access control functionalities.
/// @dev Implements the IRoleAccessControl interface.
contract RoleAccessControlFacet is IRoleAccessControl {
    /// @dev Modifier to restrict access to only role admin. Reverts if the caller does not have the ROLE_ADMIN role.
    modifier onlyRoleAdmin() {
        if (!RoleAccessControl.hasRole(msg.sender, RoleAccessControl.ROLE_ADMIN)) {
            revert RoleAccessControl.InvalidRoleAccess(msg.sender, RoleAccessControl.ROLE_ADMIN);
        }
        _;
    }

    constructor() {}

    /// @dev Checks if an account has a specific role.
    /// @param account The address of the account to check.
    /// @param role The role to check for.
    /// @return bool True if the account has the role, false otherwise.
    function hasRole(address account, bytes32 role) external view returns (bool) {
        return RoleAccessControl.hasRole(account, role);
    }

    /// @dev Grants a specific role to an account. Only callable by an account with the ROLE_ADMIN role.
    /// @param account The address of the account to grant the role to.
    /// @param role The role to grant.
    function grantRole(address account, bytes32 role) external onlyRoleAdmin {
        RoleAccessControl.grantRole(account, role);
    }

    /// @dev Revokes a specific role from an account. Only callable by an account with the ROLE_ADMIN role.
    /// @param account The address of the account to revoke the role from.
    /// @param role The role to revoke.
    function revokeRole(address account, bytes32 role) external onlyRoleAdmin {
        RoleAccessControl.revokeRole(account, role);
    }

    /// @dev Revokes all roles from an account. Only callable by an account with the ROLE_ADMIN role.
    /// @param account The address of the account to revoke all roles from.
    function revokeAllRole(address account) external onlyRoleAdmin {
        RoleAccessControl.revokeAllRole(account);
    }
}
