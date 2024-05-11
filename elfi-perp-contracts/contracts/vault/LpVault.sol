// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./Vault.sol";

contract LpVault is Vault {
    constructor(address _admin) Vault(_admin) {}
}
