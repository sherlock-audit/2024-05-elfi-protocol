// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library AddressUtils {
    uint256 public constant TEST = 1000;

    error AddressZero();

    function validEmpty(address addr) external pure {
        if (addr == address(0)) {
            revert AddressZero();
        }
    }

}
