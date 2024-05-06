// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../vault/TradeVault.sol";
import "../vault/LpVault.sol";
import "../vault/PortfolioVault.sol";

interface IVault {

    function getTradeVault() external view returns (TradeVault);

    function getLpVault() external view returns (LpVault);

    function getPortfolioVault() external view returns (PortfolioVault);

    function getTradeVaultAddress() external view returns (address);

    function getLpVaultAddress() external view returns (address);

    function getPortfolioVaultAddress() external view returns (address);
    
}
