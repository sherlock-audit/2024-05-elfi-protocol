// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "../interfaces/IWETH.sol";
import "../vault/Vault.sol";
import "../storage/AppConfig.sol";
import "../utils/Errors.sol";

library VaultProcess {

    /// @dev Transfers out tokens from the vault to a receiver
    /// @param vault The address of the vault
    /// @param token The address of the token to transfer
    /// @param receiver The address of the receiver
    /// @param amount The amount of tokens to transfer
    /// @return success A boolean indicating if the transfer was successful
    function transferOut(address vault, address token, address receiver, uint256 amount) external returns (bool) {
        return transferOut(vault, token, receiver, amount, false);
    }

    /// @dev Transfers out tokens from the vault to a receiver with an option to skip balance check
    /// @param vault The address of the vault
    /// @param token The address of the token to transfer
    /// @param receiver The address of the receiver
    /// @param amount The amount of tokens to transfer
    /// @param skipBalanceNotEnough A boolean to skip balance check if true
    /// @return success A boolean indicating if the transfer was successful
    function transferOut(
        address vault,
        address token,
        address receiver,
        uint256 amount,
        bool skipBalanceNotEnough
    ) public returns (bool) {
        if (amount == 0) {
            return false;
        }
        uint256 tokenBalance = IERC20(token).balanceOf(vault);
        if (tokenBalance >= amount) {
            Vault(vault).transferOut(token, receiver, amount);
            return true;
        } else if (!skipBalanceNotEnough) {
            revert Errors.TransferErrorWithVaultBalanceNotEnough(vault, token, receiver, amount);
        }
        return false;
    }

    /// @dev Attempts to transfer out tokens from the vault to a receiver
    /// @param vault The address of the vault
    /// @param token The address of the token to transfer
    /// @param receiver The address of the receiver
    /// @param amount The amount of tokens to transfer
    /// @return transferredAmount The amount of tokens actually transferred
    function tryTransferOut(address vault, address token, address receiver, uint256 amount) public returns (uint256) {
        if (amount == 0) {
            return 0;
        }
        uint256 tokenBalance = IERC20(token).balanceOf(vault);
        if (tokenBalance == 0) {
            return 0;
        }
        if (tokenBalance >= amount) {
            Vault(vault).transferOut(token, receiver, amount);
            return amount;
        } else {
            Vault(vault).transferOut(token, receiver, tokenBalance);
            return tokenBalance;
        }
    }

    /// @dev Withdraws Ether to a receiver
    /// @param receiver The address of the receiver
    /// @param amount The amount of Ether to withdraw
    function withdrawEther(address receiver, uint256 amount) internal {
        address wrapperToken = AppConfig.getChainConfig().wrapperToken;
        IWETH(wrapperToken).withdraw(amount);
        safeTransferETH(receiver, amount);
    }

    /// @dev Safely transfers Ether to a receiver
    /// @param to The address of the receiver
    /// @param value The amount of Ether to transfer
    function safeTransferETH(address to, uint256 value) public {
        (bool success, ) = to.call{ value: value }(new bytes(0));
        require(success, "STE");
    }
}