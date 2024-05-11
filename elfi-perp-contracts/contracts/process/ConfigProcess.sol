// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IConfig.sol";
import "../storage/AppConfig.sol";
import "../storage/AppTradeConfig.sol";
import "../storage/AppPoolConfig.sol";
import "../storage/AppVaultConfig.sol";
import "../storage/UsdPool.sol";
import "../utils/Errors.sol";

library ConfigProcess {
    using UsdPool for UsdPool.Props;
    using EnumerableSet for EnumerableSet.AddressSet;

    function getConfig() external view returns (IConfig.CommonConfigParams memory config) {
        config.chainConfig = AppConfig.getChainConfig();
        config.tradeConfig = AppTradeConfig.getTradeConfig();
        config.stakeConfig = AppPoolConfig.getStakeConfig();
        config.uniswapRouter = AppConfig.getUniswapRouter();
    }

    function setConfig(IConfig.CommonConfigParams calldata params) external {
        AppConfig.setChainConfig(params.chainConfig);
        AppTradeConfig.setTradeConfig(params.tradeConfig);
        AppPoolConfig.setStakeConfig(params.stakeConfig);
        AppConfig.setUniswapRouter(params.uniswapRouter);
    }

    function setUniswapRouter(address router) external {
        AppConfig.setUniswapRouter(router);
    }

    function getPoolConfig(address stakeToken) public view returns (AppPoolConfig.LpPoolConfig memory) {
        return AppPoolConfig.getLpPoolConfig(stakeToken);
    }

    function setPoolConfig(IConfig.LpPoolConfigParams memory params) external {
        AppPoolConfig.setLpPoolConfig(params.stakeToken, params.config);
    }

    function getUsdPoolConfig() external view returns (AppPoolConfig.UsdPoolConfig memory) {
        return AppPoolConfig.getUsdPoolConfig();
    }

    function setUsdPoolConfig(IConfig.UsdPoolConfigParams calldata params) external {
        AppPoolConfig.setUsdPoolConfig(params.config);
        UsdPool.Props storage pool = UsdPool.load();
        pool.addSupportStableTokens(params.config.supportStableTokens);
    }

    function getSymbolConfig(bytes32 code) external view returns (AppConfig.SymbolConfig memory) {
        return AppConfig.getSymbolConfig(code);
    }

    function setSymbolConfig(IConfig.SymbolConfigParams calldata params) external {
        AppConfig.setSymbolConfig(params.symbol, params.config);
    }

    function setVaultConfig(IConfig.VaultConfigParams calldata params) external {
        AppVaultConfig.setLpVault(params.lpVault);
        AppVaultConfig.setTradeVault(params.tradeVault);
        AppVaultConfig.setPortfolioVault(params.portfolioVault);
    }
}
