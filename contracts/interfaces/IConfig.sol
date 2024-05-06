// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../storage/AppConfig.sol";
import "../storage/AppTradeConfig.sol";
import "../storage/AppPoolConfig.sol";

interface IConfig {
    struct CommonConfigParams {
        AppConfig.ChainConfig chainConfig;
        AppTradeConfig.TradeConfig tradeConfig;
        AppPoolConfig.StakeConfig stakeConfig;
        address uniswapRouter;
    }

    struct LpPoolConfigParams {
        address stakeToken;
        AppPoolConfig.LpPoolConfig config;
    }

    struct UsdPoolConfigParams {
        AppPoolConfig.UsdPoolConfig config;
    }

    struct SymbolConfigParams {
        bytes32 symbol;
        AppConfig.SymbolConfig config;
    }

    struct VaultConfigParams {
        address lpVault;
        address tradeVault;
        address portfolioVault;
    }
}
