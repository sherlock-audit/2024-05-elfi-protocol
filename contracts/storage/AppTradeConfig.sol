// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./AppStorage.sol";
import "./AppTradeTokenConfig.sol";

library AppTradeConfig {
    using AppStorage for AppStorage.Props;

    // -- trade config keys --
    bytes32 public constant TRADE_TOKENS = keccak256(abi.encode("TRADE_TOKENS"));
    bytes32 public constant MIN_ORDER_MARGIN_USD = keccak256(abi.encode("MIN_ORDER_MARGIN_USD"));
    bytes32 public constant AVAILABLE_COLLATERAL_RATIO = keccak256(abi.encode("AVAILABLE_COLLATERAL_RATIO"));
    bytes32 public constant CROSS_LTV_LIMIT = keccak256(abi.encode("CROSS_LTV_LIMIT"));
    bytes32 public constant MAX_MAINTENANCE_MARGIN_RATE = keccak256(abi.encode("MAX_MAINTENANCE_MARGIN_RATE"));
    bytes32 public constant FUNDING_FEE_BASE_RATE = keccak256(abi.encode("FUNDING_FEE_BASE_RATE"));
    bytes32 public constant MAX_FUNDING_BASE_RATE = keccak256(abi.encode("MAX_FUNDING_BASE_RATE"));
    bytes32 public constant TRADING_FEE_STAKING_REWARDS_RATIO =
        keccak256(abi.encode("TRADING_FEE_STAKING_REWARDS_RATIO"));
    bytes32 public constant TRADING_FEE_POOL_REWARDS_RATIO = keccak256(abi.encode("TRADING_FEE_POOL_REWARDS_RATIO"));
    bytes32 public constant TRADING_FEE_USD_POOL_REWARDS_RATIO =
        keccak256(abi.encode("TRADING_FEE_USD_POOL_REWARDS_RATIO"));
    bytes32 public constant BORROWING_FEE_STAKING_REWARDS_RATIO =
        keccak256(abi.encode("BORROWING_FEE_STAKING_REWARDS_RATIO"));
    bytes32 public constant BORROWING_FEE_POOL_REWARDS_RATIO =
        keccak256(abi.encode("BORROWING_FEE_POOL_REWARDS_RATIO"));
    bytes32 public constant AUTO_REDUCE_PROFIT_FACTOR = keccak256(abi.encode("AUTO_REDUCE_PROFIT_FACTOR"));
    bytes32 public constant AUTO_REDUCE_LIQUIDITY_FACTOR = keccak256(abi.encode("AUTO_REDUCE_LIQUIDITY_FACTOR"));
    bytes32 public constant SWAP_SLIPPER_TOKEN_FACTOR = keccak256(abi.encode("SWAP_SLIPPER_TOKEN_FACTOR"));

    struct TradeConfig {
        address[] tradeTokens;
        AppTradeTokenConfig.TradeTokenConfig[] tradeTokenConfigs;
        uint256 minOrderMarginUSD;
        uint256 availableCollateralRatio;
        uint256 crossLtvLimit;
        uint256 maxMaintenanceMarginRate;
        uint256 fundingFeeBaseRate;
        uint256 maxFundingBaseRate;
        uint256 tradingFeeStakingRewardsRatio;
        uint256 tradingFeePoolRewardsRatio;
        uint256 tradingFeeUsdPoolRewardsRatio;
        uint256 borrowingFeeStakingRewardsRatio;
        uint256 borrowingFeePoolRewardsRatio;
        uint256 autoReduceProfitFactor;
        uint256 autoReduceLiquidityFactor;
        uint256 swapSlipperTokenFactor;
    }

    function getTradeConfig() external view returns (TradeConfig memory config) {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.TRADE_CONFIG;
        config.tradeTokens = app.getAddressArrayValues(keccak256(abi.encode(key, TRADE_TOKENS)));
        config.tradeTokenConfigs = new AppTradeTokenConfig.TradeTokenConfig[](config.tradeTokens.length);
        for (uint256 i; i < config.tradeTokens.length; i++) {
            config.tradeTokenConfigs[i] = AppTradeTokenConfig.getTradeTokenConfig(config.tradeTokens[i]);
        }
        config.minOrderMarginUSD = app.getUintValue(keccak256(abi.encode(key, MIN_ORDER_MARGIN_USD)));
        config.availableCollateralRatio = app.getUintValue(keccak256(abi.encode(key, AVAILABLE_COLLATERAL_RATIO)));
        config.crossLtvLimit = app.getUintValue(keccak256(abi.encode(key, CROSS_LTV_LIMIT)));
        config.maxMaintenanceMarginRate = app.getUintValue(keccak256(abi.encode(key, MAX_MAINTENANCE_MARGIN_RATE)));
        config.fundingFeeBaseRate = app.getUintValue(keccak256(abi.encode(key, FUNDING_FEE_BASE_RATE)));
        config.maxFundingBaseRate = app.getUintValue(keccak256(abi.encode(key, MAX_FUNDING_BASE_RATE)));
        config.tradingFeeStakingRewardsRatio = app.getUintValue(
            keccak256(abi.encode(key, TRADING_FEE_STAKING_REWARDS_RATIO))
        );
        config.tradingFeePoolRewardsRatio = app.getUintValue(
            keccak256(abi.encode(key, TRADING_FEE_POOL_REWARDS_RATIO))
        );
        config.tradingFeeUsdPoolRewardsRatio = app.getUintValue(
            keccak256(abi.encode(key, TRADING_FEE_USD_POOL_REWARDS_RATIO))
        );
        config.borrowingFeeStakingRewardsRatio = app.getUintValue(
            keccak256(abi.encode(key, BORROWING_FEE_STAKING_REWARDS_RATIO))
        );
        config.borrowingFeePoolRewardsRatio = app.getUintValue(
            keccak256(abi.encode(key, BORROWING_FEE_POOL_REWARDS_RATIO))
        );
        config.autoReduceProfitFactor = app.getUintValue(keccak256(abi.encode(key, AUTO_REDUCE_PROFIT_FACTOR)));
        config.autoReduceLiquidityFactor = app.getUintValue(keccak256(abi.encode(key, AUTO_REDUCE_LIQUIDITY_FACTOR)));
        config.swapSlipperTokenFactor = app.getUintValue(keccak256(abi.encode(key, SWAP_SLIPPER_TOKEN_FACTOR)));
    }

    function setTradeConfig(TradeConfig memory config) external {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.TRADE_CONFIG;
        address[] memory oldTokens = app.getAddressArrayValues(keccak256(abi.encode(key, TRADE_TOKENS)));
        for (uint256 i; i < oldTokens.length; i++) {
            AppTradeTokenConfig.deleteTradeTokenConfig(oldTokens[i]);
        }
        app.setAddressArrayValues(keccak256(abi.encode(key, TRADE_TOKENS)), config.tradeTokens);
        for (uint256 i; i < config.tradeTokens.length; i++) {
            AppTradeTokenConfig.setTradeTokenConfig(config.tradeTokens[i], config.tradeTokenConfigs[i]);
        }
        app.setUintValue(keccak256(abi.encode(key, MIN_ORDER_MARGIN_USD)), config.minOrderMarginUSD);
        app.setUintValue(keccak256(abi.encode(key, AVAILABLE_COLLATERAL_RATIO)), config.availableCollateralRatio);
        app.setUintValue(keccak256(abi.encode(key, CROSS_LTV_LIMIT)), config.crossLtvLimit);
        app.setUintValue(keccak256(abi.encode(key, MAX_MAINTENANCE_MARGIN_RATE)), config.maxMaintenanceMarginRate);
        app.setUintValue(keccak256(abi.encode(key, FUNDING_FEE_BASE_RATE)), config.fundingFeeBaseRate);
        app.setUintValue(keccak256(abi.encode(key, MAX_FUNDING_BASE_RATE)), config.maxFundingBaseRate);
        app.setUintValue(
            keccak256(abi.encode(key, TRADING_FEE_STAKING_REWARDS_RATIO)),
            config.tradingFeeStakingRewardsRatio
        );
        app.setUintValue(keccak256(abi.encode(key, TRADING_FEE_POOL_REWARDS_RATIO)), config.tradingFeePoolRewardsRatio);
        app.setUintValue(
            keccak256(abi.encode(key, TRADING_FEE_USD_POOL_REWARDS_RATIO)),
            config.tradingFeeUsdPoolRewardsRatio
        );
        app.setUintValue(
            keccak256(abi.encode(key, BORROWING_FEE_STAKING_REWARDS_RATIO)),
            config.borrowingFeeStakingRewardsRatio
        );
        app.setUintValue(
            keccak256(abi.encode(key, BORROWING_FEE_POOL_REWARDS_RATIO)),
            config.borrowingFeePoolRewardsRatio
        );
        app.setUintValue(keccak256(abi.encode(key, AUTO_REDUCE_PROFIT_FACTOR)), config.autoReduceProfitFactor);
        app.setUintValue(keccak256(abi.encode(key, AUTO_REDUCE_LIQUIDITY_FACTOR)), config.autoReduceLiquidityFactor);
        app.setUintValue(keccak256(abi.encode(key, SWAP_SLIPPER_TOKEN_FACTOR)), config.swapSlipperTokenFactor);
    }

}
