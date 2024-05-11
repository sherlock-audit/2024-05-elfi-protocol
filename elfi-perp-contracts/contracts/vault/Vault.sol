// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import "../utils/TransferUtils.sol";

contract Vault is AccessControl {
    error AddressSelfNotSupported(address self);

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(address admin) {
        _grantRole(ADMIN_ROLE, admin);
    }

    function transferOut(address token, address receiver, uint256 amount) external onlyRole(ADMIN_ROLE) {
        if (receiver == address(this)) {
            revert AddressSelfNotSupported(receiver);
        }
        TransferUtils.transfer(token, receiver, amount);
    }

    function grantAdmin(address newAdmin) external onlyRole(ADMIN_ROLE) {
        _grantRole(ADMIN_ROLE, newAdmin);
    }

    function revokeAdmin(address admin) external onlyRole(ADMIN_ROLE) {
        _revokeRole(ADMIN_ROLE, admin);
    }
}
