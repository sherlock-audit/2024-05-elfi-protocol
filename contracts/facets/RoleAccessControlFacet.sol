// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IRoleAccessControl.sol";
import "../storage/RoleAccessControl.sol";

contract RoleAccessControlFacet is IRoleAccessControl {
    modifier onlyRoleAdmin() {
        if (!RoleAccessControl.hasRole(msg.sender, RoleAccessControl.ROLE_ADMIN)) {
            revert RoleAccessControl.InvalidRoleAccess(msg.sender, RoleAccessControl.ROLE_ADMIN);
        }
        _;
    }

    constructor() {}

    function hasRole(address account, bytes32 role) external view returns (bool) {
        return RoleAccessControl.hasRole(account, role);
    }

    function grantRole(address account, bytes32 role) external onlyRoleAdmin {
        RoleAccessControl.grantRole(account, role);
    }

    function revokeRole(address account, bytes32 role) external onlyRoleAdmin {
        RoleAccessControl.revokeRole(account, role);
    }

    function revokeAllRole(address account) external onlyRoleAdmin {
        RoleAccessControl.revokeAllRole(account);
    }
}
