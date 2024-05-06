// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library TransferUtils {
    uint256 private constant TRANSFER_GAS_LIMIT = 200000;

    error TokenTransferError(address token, address receiver, uint256 amount);

    function transfer(address token, address receiver, uint256 amount) external {
        if (amount == 0) {
            return;
        }
        bool success = transferWithGasLimit(IERC20(token), receiver, amount, TRANSFER_GAS_LIMIT);
        if (!success) {
            revert TokenTransferError(token, receiver, amount);
        }
    }

    function transferWithGasLimit(IERC20 token, address to, uint256 amount, uint256 gasLimit) internal returns (bool) {
        bytes memory data = abi.encodeWithSelector(token.transfer.selector, to, amount);
        (bool success, bytes memory returnData) = address(token).call{ gas: gasLimit }(data);
        if (!success) {
            return false;
        }
        if (returnData.length > 0 && !abi.decode(returnData, (bool))) {
            return false;
        }
        return true;
    }
}
