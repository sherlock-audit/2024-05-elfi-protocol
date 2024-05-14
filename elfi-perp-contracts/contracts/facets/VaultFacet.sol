// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IVault.sol";
import "../vault/TradeVault.sol";
import "../vault/LpVault.sol";
import "../vault/PortfolioVault.sol";
import "../storage/AppVaultConfig.sol";

contract VaultFacet is IVault {
    function getTradeVault() external view override returns (TradeVault) {
        return TradeVault(AppVaultConfig.getTradeVault());
    }

    function getLpVault() external view override returns (LpVault) {
        return LpVault(AppVaultConfig.getLpVault());
    }

    function getPortfolioVault() external view override returns (PortfolioVault) {
        return PortfolioVault(AppVaultConfig.getPortfolioVault());
    }

    function getTradeVaultAddress() external view override returns (address) {
        return AppVaultConfig.getTradeVault();
    }

    function getLpVaultAddress() external view override returns (address) {
        return AppVaultConfig.getLpVault();
    }

    function getPortfolioVaultAddress() external view override returns (address) {
        return AppVaultConfig.getPortfolioVault();
    }
}
