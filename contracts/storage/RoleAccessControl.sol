// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title RoleAccessControl
/// @dev Library for managing role-based access control.
library RoleAccessControl {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    bytes32 internal constant ACCESS_CONTROL_KEY = keccak256(abi.encode("xyz.elfi.storage.AccessControl"));

    bytes32 constant ROLE_ADMIN = "ADMIN";
    bytes32 constant ROLE_UPGRADE = "UPGRADE";
    bytes32 constant ROLE_CONFIG = "CONFIG";
    bytes32 constant ROLE_KEEPER = "KEEPER";

    /// @dev Error thrown when an account does not have the required role.
    error InvalidRoleAccess(address account, bytes32 role);

    /// @dev Error thrown when an invalid role name is provided.
    error InvalidRoleName(bytes32 role);

    struct Props {
        mapping(address => EnumerableSet.Bytes32Set) accountRoles;
    }

    /// @dev Loads the role access control storage.
    /// @return self The role access control storage.
    function load() public pure returns (Props storage self) {
        bytes32 s = ACCESS_CONTROL_KEY;
        assembly {
            self.slot := s
        }
    }

    /// @dev Checks if the caller has the specified role.
    /// @param role The role to check.
    function checkRole(bytes32 role) internal view {
        if (!hasRole(msg.sender, role)) {
            revert InvalidRoleAccess(msg.sender, role);
        }
    }

    /// @dev Checks if the caller has the specified role.
    /// @param role The role to check.
    /// @return True if the caller has the role, false otherwise.
    function hasRole(bytes32 role) internal view returns (bool) {
        return hasRole(msg.sender, role);
    }

    /// @dev Checks if an account has the specified role.
    /// @param account The account to check.
    /// @param role The role to check.
    /// @return True if the account has the role, false otherwise.
    function hasRole(address account, bytes32 role) internal view returns (bool) {
        Props storage self = load();
        return self.accountRoles[account].contains(role);
    }

    /// @dev Grants a role to an account.
    /// @param account The account to grant the role to.
    /// @param role The role to grant.
    function grantRole(address account, bytes32 role) internal {
        Props storage self = load();
        self.accountRoles[account].add(role);
    }

    /// @dev Revokes a role from an account.
    /// @param account The account to revoke the role from.
    /// @param role The role to revoke.
    function revokeRole(address account, bytes32 role) internal {
        Props storage self = load();
        if (self.accountRoles[account].contains(role)) {
            self.accountRoles[account].remove(role);
        }
    }

    /// @dev Revokes all roles from an account.
    /// @param account The account to revoke all roles from.
    function revokeAllRole(address account) internal {
        Props storage self = load();
        delete self.accountRoles[account];
    }
}