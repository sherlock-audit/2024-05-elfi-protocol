// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library TokenUtils {
    function decimals(address token) external view returns (uint8) {
        return IERC20Metadata(token).decimals();
    }

    function totalSupply(address token) external view returns (uint256) {
        return IERC20(token).totalSupply();
    }
}
