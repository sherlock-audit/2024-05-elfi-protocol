// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title TransferUtils
/// @dev A library to safely transfer ERC20 tokens with gas limit and error handling.
library TransferUtils {
    /// @dev The gas limit for ERC20 token transfers to prevent out of gas errors.
    uint256 private constant TRANSFER_GAS_LIMIT = 200000;

    /// @dev Emitted when a token transfer fails.
    /// @param token The address of the token contract
    /// @param receiver The address of the receiver
    /// @param amount The amount of tokens attempted to transfer
    error TokenTransferError(address token, address receiver, uint256 amount);

    /// @notice Transfers a specified amount of ERC20 tokens to a receiver.
    /// @dev Reverts with TokenTransferError if the transfer fails.
    /// @param token The address of the token contract
    /// @param receiver The address of the receiver
    /// @param amount The amount of tokens to transfer
    function transfer(address token, address receiver, uint256 amount) external {
        if (amount == 0) {
            return;
        }
        bool success = transferWithGasLimit(IERC20(token), receiver, amount, TRANSFER_GAS_LIMIT);
        if (!success) {
            revert TokenTransferError(token, receiver, amount);
        }
    }

    /// @dev Attempts to transfer tokens with a specified gas limit.
    /// @param token The ERC20 token contract address
    /// @param to The address of the receiver
    /// @param amount The amount of tokens to transfer
    /// @param gasLimit The gas limit for the transfer
    /// @return success True if the transfer was successful, false otherwise
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
