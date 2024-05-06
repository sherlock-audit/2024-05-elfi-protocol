// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./AppStorage.sol";

library AppTradeTokenConfig {
    using AppStorage for AppStorage.Props;

    // -- trade token config keys --
    bytes32 public constant IS_SUPPORT_COLLATERAL = keccak256(abi.encode("IS_SUPPORT_COLLATERAL"));
    bytes32 public constant PRECISION = keccak256(abi.encode("PRECISION"));
    bytes32 public constant DISCOUNT = keccak256(abi.encode("DISCOUNT"));
    bytes32 public constant COLLATERAL_USER_CAP = keccak256(abi.encode("COLLATERAL_USER_CAP"));
    bytes32 public constant COLLATERAL_TOTAL_CAP = keccak256(abi.encode("COLLATERAL_TOTAL_CAP"));
    bytes32 public constant LIABILITY_USER_CAP = keccak256(abi.encode("LIABILITY_USER_CAP"));
    bytes32 public constant LIABILITY_TOTAL_CAP = keccak256(abi.encode("LIABILITY_TOTAL_CAP"));
    bytes32 public constant INTEREST_RATE_FACTOR = keccak256(abi.encode("INTEREST_RATE_FACTOR"));
    bytes32 public constant LIQUIDATION_FACTOR = keccak256(abi.encode("LIQUIDATION_FACTOR"));

    struct TradeTokenConfig {
        bool isSupportCollateral;
        uint256 precision;
        uint256 discount;
        uint256 collateralUserCap;
        uint256 collateralTotalCap;
        uint256 liabilityUserCap;
        uint256 liabilityTotalCap;
        uint256 interestRateFactor;
        uint256 liquidationFactor;
    }

    function getTradeTokenConfig(address token) public view returns (TradeTokenConfig memory) {
        TradeTokenConfig memory tradeTokenConfig;
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.TRADE_TOKEN_CONFIG;
        if (!app.containsAddress(key, token)) {
            return tradeTokenConfig;
        }
        tradeTokenConfig.isSupportCollateral = app.getBoolValue(
            keccak256(abi.encode(key, token, IS_SUPPORT_COLLATERAL))
        );
        tradeTokenConfig.precision = app.getUintValue(keccak256(abi.encode(key, token, PRECISION)));
        tradeTokenConfig.discount = app.getUintValue(keccak256(abi.encode(key, token, DISCOUNT)));
        tradeTokenConfig.collateralUserCap = app.getUintValue(keccak256(abi.encode(key, token, COLLATERAL_USER_CAP)));
        tradeTokenConfig.collateralTotalCap = app.getUintValue(keccak256(abi.encode(key, token, COLLATERAL_TOTAL_CAP)));
        tradeTokenConfig.liabilityUserCap = app.getUintValue(keccak256(abi.encode(key, token, LIABILITY_USER_CAP)));
        tradeTokenConfig.liabilityTotalCap = app.getUintValue(keccak256(abi.encode(key, token, LIABILITY_TOTAL_CAP)));
        tradeTokenConfig.interestRateFactor = app.getUintValue(keccak256(abi.encode(key, token, INTEREST_RATE_FACTOR)));
        tradeTokenConfig.liquidationFactor = app.getUintValue(keccak256(abi.encode(key, token, LIQUIDATION_FACTOR)));
        return tradeTokenConfig;
    }

    function setTradeTokenConfig(address token, TradeTokenConfig memory config) internal {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.TRADE_TOKEN_CONFIG;
        app.addAddress(key, token);
        app.setBoolValue(keccak256(abi.encode(key, token, IS_SUPPORT_COLLATERAL)), config.isSupportCollateral);
        app.setUintValue(keccak256(abi.encode(key, token, PRECISION)), config.precision);
        app.setUintValue(keccak256(abi.encode(key, token, DISCOUNT)), config.discount);
        app.setUintValue(keccak256(abi.encode(key, token, COLLATERAL_USER_CAP)), config.collateralUserCap);
        app.setUintValue(keccak256(abi.encode(key, token, COLLATERAL_TOTAL_CAP)), config.collateralTotalCap);
        app.setUintValue(keccak256(abi.encode(key, token, LIABILITY_USER_CAP)), config.liabilityUserCap);
        app.setUintValue(keccak256(abi.encode(key, token, LIABILITY_TOTAL_CAP)), config.liabilityTotalCap);
        app.setUintValue(keccak256(abi.encode(key, token, INTEREST_RATE_FACTOR)), config.interestRateFactor);
        app.setUintValue(keccak256(abi.encode(key, token, LIQUIDATION_FACTOR)), config.liquidationFactor);
    }

    function deleteTradeTokenConfig(address token) internal {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.TRADE_TOKEN_CONFIG;
        if (!app.containsAddress(key, token)) {
            return;
        }
        app.removeAddress(key, token);
        app.deleteBoolValue(keccak256(abi.encode(key, token, IS_SUPPORT_COLLATERAL)));
        app.deleteUintValue(keccak256(abi.encode(key, token, PRECISION)));
        app.deleteUintValue(keccak256(abi.encode(key, token, DISCOUNT)));
        app.deleteUintValue(keccak256(abi.encode(key, token, COLLATERAL_USER_CAP)));
        app.deleteUintValue(keccak256(abi.encode(key, token, COLLATERAL_TOTAL_CAP)));
        app.deleteUintValue(keccak256(abi.encode(key, token, LIABILITY_USER_CAP)));
        app.deleteUintValue(keccak256(abi.encode(key, token, LIABILITY_TOTAL_CAP)));
        app.deleteUintValue(keccak256(abi.encode(key, token, INTEREST_RATE_FACTOR)));
        app.deleteUintValue(keccak256(abi.encode(key, token, LIQUIDATION_FACTOR)));
    }
}
