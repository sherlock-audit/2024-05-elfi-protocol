// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./AppStorage.sol";

library AppPoolConfig {
    using AppStorage for AppStorage.Props;

    // -- stake config keys --
    bytes32 public constant COLLATERAL_PROTECT_FACTOR = keccak256(abi.encode("COLLATERAL_PROTECT_FACTOR"));
    bytes32 public constant COLLATERAL_FACTOR = keccak256(abi.encode("COLLATERAL_FACTOR"));
    bytes32 public constant MIN_PRECISION_MULTIPLE = keccak256(abi.encode("MIN_PRECISION_MULTIPLE"));
    bytes32 public constant MINT_FEE_STAKING_REWARDS_RATIO = keccak256(abi.encode("MINT_FEE_STAKING_REWARDS_RATIO"));
    bytes32 public constant MINT_FEE_POOL_REWARDS_RATIO = keccak256(abi.encode("MINT_FEE_POOL_REWARDS_RATIO"));
    bytes32 public constant REDEEM_FEE_STAKING_REWARDS_RATIO =
        keccak256(abi.encode("REDEEM_FEE_STAKING_REWARDS_RATIO"));
    bytes32 public constant REDEEM_FEE_POOL_REWARDS_RATIO = keccak256(abi.encode("REDEEM_FEE_POOL_REWARDS_RATIO"));
    bytes32 public constant POOL_REWARDS_INTERVAL_LIMIT = keccak256(abi.encode("POOL_REWARDS_INTERVAL_LIMIT"));
    bytes32 public constant MIN_APR = keccak256(abi.encode("MIN_APR"));
    bytes32 public constant MAX_APR = keccak256(abi.encode("MAX_APR"));

    // -- pool config keys --
    bytes32 public constant POOL_LIQUIDITY_LIMIT = keccak256(abi.encode("POOL_LIQUIDITY_LIMIT"));
    bytes32 public constant MINT_FEE_RATE = keccak256(abi.encode("MINT_FEE_RATE"));
    bytes32 public constant REDEEM_FEE_RATE = keccak256(abi.encode("REDEEM_FEE_RATE"));
    bytes32 public constant UNSETTLED_RATIO_LIMIT = keccak256(abi.encode("UNSETTLED_RATIO_LIMIT"));
    bytes32 public constant SUPPORT_STABLE_TOKENS = keccak256(abi.encode("SUPPORT_STABLE_TOKENS"));
    bytes32 public constant STABLE_TOKENS_BORROWING_INTEREST_RATE =
        keccak256(abi.encode("STABLE_TOKENS_BORROWING_INTEREST_RATE"));

    bytes32 public constant BASE_INTEREST_RATE = keccak256(abi.encode("BASE_INTEREST_RATE"));
    bytes32 public constant POOL_PNL_RATIO_LIMIT = keccak256(abi.encode("POOL_PNL_RATIO_LIMIT"));
    bytes32 public constant UNSETTLED_BASE_TOKEN_RATIO_LIMIT =
        keccak256(abi.encode("UNSETTLED_BASE_TOKEN_RATIO_LIMIT"));
    bytes32 public constant UNSETTLED_STABLE_TOKEN_RATIO_LIMIT =
        keccak256(abi.encode("UNSETTLED_STABLE_TOKEN_RATIO_LIMIT"));
    bytes32 public constant POOL_STABLE_TOKEN_RATIO_LIMIT = keccak256(abi.encode("POOL_STABLE_TOKEN_RATIO_LIMIT"));
    bytes32 public constant POOL_STABLE_TOKEN_LOSS_LIMIT = keccak256(abi.encode("POOL_STABLE_TOKEN_LOSS_LIMIT"));
    bytes32 public constant ASSET_TOKENS = keccak256(abi.encode("ASSET_TOKENS"));

    struct StakeConfig {
        uint256 collateralProtectFactor;
        uint256 collateralFactor;
        uint256 minPrecisionMultiple;
        uint256 mintFeeStakingRewardsRatio;
        uint256 mintFeePoolRewardsRatio;
        uint256 redeemFeeStakingRewardsRatio;
        uint256 redeemFeePoolRewardsRatio;
        uint256 poolRewardsIntervalLimit;
        uint256 minApr;
        uint256 maxApr;
    }

    struct UsdPoolConfig {
        uint256 poolLiquidityLimit;
        uint256 mintFeeRate;
        uint256 redeemFeeRate;
        uint256 unsettledRatioLimit;
        address[] supportStableTokens;
        uint256[] stableTokensBorrowingInterestRate;
    }

    struct LpPoolConfig {
        uint256 baseInterestRate;
        uint256 poolLiquidityLimit;
        uint256 mintFeeRate;
        uint256 redeemFeeRate;
        uint256 poolPnlRatioLimit;
        uint256 unsettledBaseTokenRatioLimit;
        uint256 unsettledStableTokenRatioLimit;
        uint256 poolStableTokenRatioLimit;
        uint256 poolStableTokenLossLimit;
        address[] assetTokens;
    }

    function getStakeConfig() external view returns (StakeConfig memory config) {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.STAKE_CONFIG;
        config.collateralProtectFactor = app.getUintValue(keccak256(abi.encode(key, COLLATERAL_PROTECT_FACTOR)));
        config.collateralFactor = app.getUintValue(keccak256(abi.encode(key, COLLATERAL_FACTOR)));
        config.minPrecisionMultiple = app.getUintValue(keccak256(abi.encode(key, MIN_PRECISION_MULTIPLE)));
        config.mintFeeStakingRewardsRatio = app.getUintValue(
            keccak256(abi.encode(key, MINT_FEE_STAKING_REWARDS_RATIO))
        );
        config.mintFeePoolRewardsRatio = app.getUintValue(keccak256(abi.encode(key, MINT_FEE_POOL_REWARDS_RATIO)));
        config.redeemFeeStakingRewardsRatio = app.getUintValue(
            keccak256(abi.encode(key, REDEEM_FEE_STAKING_REWARDS_RATIO))
        );
        config.redeemFeePoolRewardsRatio = app.getUintValue(keccak256(abi.encode(key, REDEEM_FEE_POOL_REWARDS_RATIO)));
        config.poolRewardsIntervalLimit = app.getUintValue(keccak256(abi.encode(key, POOL_REWARDS_INTERVAL_LIMIT)));
        config.minApr = app.getUintValue(keccak256(abi.encode(key, MIN_APR)));
        config.maxApr = app.getUintValue(keccak256(abi.encode(key, MAX_APR)));
    }

    function setStakeConfig(StakeConfig memory config) external {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.STAKE_CONFIG;
        app.setUintValue(keccak256(abi.encode(key, COLLATERAL_PROTECT_FACTOR)), config.collateralProtectFactor);
        app.setUintValue(keccak256(abi.encode(key, COLLATERAL_FACTOR)), config.collateralFactor);
        app.setUintValue(keccak256(abi.encode(key, MIN_PRECISION_MULTIPLE)), config.minPrecisionMultiple);
        app.setUintValue(keccak256(abi.encode(key, MINT_FEE_STAKING_REWARDS_RATIO)), config.mintFeeStakingRewardsRatio);
        app.setUintValue(keccak256(abi.encode(key, MINT_FEE_POOL_REWARDS_RATIO)), config.mintFeePoolRewardsRatio);
        app.setUintValue(
            keccak256(abi.encode(key, REDEEM_FEE_STAKING_REWARDS_RATIO)),
            config.redeemFeeStakingRewardsRatio
        );
        app.setUintValue(keccak256(abi.encode(key, REDEEM_FEE_POOL_REWARDS_RATIO)), config.redeemFeePoolRewardsRatio);
        app.setUintValue(keccak256(abi.encode(key, POOL_REWARDS_INTERVAL_LIMIT)), config.poolRewardsIntervalLimit);
        app.setUintValue(keccak256(abi.encode(key, MIN_APR)), config.minApr);
        app.setUintValue(keccak256(abi.encode(key, MAX_APR)), config.maxApr);
    }

    function getUsdPoolConfig() external view returns (UsdPoolConfig memory config) {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.USD_POOL_CONFIG;
        config.poolLiquidityLimit = app.getUintValue(keccak256(abi.encode(key, POOL_LIQUIDITY_LIMIT)));
        config.mintFeeRate = app.getUintValue(keccak256(abi.encode(key, MINT_FEE_RATE)));
        config.redeemFeeRate = app.getUintValue(keccak256(abi.encode(key, REDEEM_FEE_RATE)));
        config.unsettledRatioLimit = app.getUintValue(keccak256(abi.encode(key, UNSETTLED_RATIO_LIMIT)));
        config.supportStableTokens = app.getAddressArrayValues(keccak256(abi.encode(key, SUPPORT_STABLE_TOKENS)));
        config.stableTokensBorrowingInterestRate = new uint256[](config.supportStableTokens.length);
        for (uint256 i; i < config.supportStableTokens.length; i++) {
            config.stableTokensBorrowingInterestRate[i] = app.getUintValue(
                keccak256(abi.encode(key, config.supportStableTokens[i], STABLE_TOKENS_BORROWING_INTEREST_RATE))
            );
        }
    }

    function setUsdPoolConfig(UsdPoolConfig memory config) external {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.USD_POOL_CONFIG;
        app.setUintValue(keccak256(abi.encode(key, POOL_LIQUIDITY_LIMIT)), config.poolLiquidityLimit);
        app.setUintValue(keccak256(abi.encode(key, MINT_FEE_RATE)), config.mintFeeRate);
        app.setUintValue(keccak256(abi.encode(key, REDEEM_FEE_RATE)), config.redeemFeeRate);
        app.setUintValue(keccak256(abi.encode(key, UNSETTLED_RATIO_LIMIT)), config.unsettledRatioLimit);
        app.setAddressArrayValues(keccak256(abi.encode(key, SUPPORT_STABLE_TOKENS)), config.supportStableTokens);
        for (uint256 i; i < config.supportStableTokens.length; i++) {
            app.setUintValue(
                keccak256(abi.encode(key, config.supportStableTokens[i], STABLE_TOKENS_BORROWING_INTEREST_RATE)),
                config.stableTokensBorrowingInterestRate[i]
            );
        }
    }

    function getLpPoolConfig(address stakeToken) external view returns (LpPoolConfig memory) {
        LpPoolConfig memory config;
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.LP_POOL_CONFIG;
        if (!app.containsAddress(key, stakeToken)) {
            return config;
        }
        config.baseInterestRate = app.getUintValue(keccak256(abi.encode(key, stakeToken, BASE_INTEREST_RATE)));
        config.poolLiquidityLimit = app.getUintValue(keccak256(abi.encode(key, stakeToken, POOL_LIQUIDITY_LIMIT)));
        config.mintFeeRate = app.getUintValue(keccak256(abi.encode(key, stakeToken, MINT_FEE_RATE)));
        config.redeemFeeRate = app.getUintValue(keccak256(abi.encode(key, stakeToken, REDEEM_FEE_RATE)));
        config.poolPnlRatioLimit = app.getUintValue(keccak256(abi.encode(key, stakeToken, POOL_PNL_RATIO_LIMIT)));
        config.unsettledBaseTokenRatioLimit = app.getUintValue(
            keccak256(abi.encode(key, stakeToken, UNSETTLED_BASE_TOKEN_RATIO_LIMIT))
        );
        config.unsettledStableTokenRatioLimit = app.getUintValue(
            keccak256(abi.encode(key, stakeToken, UNSETTLED_STABLE_TOKEN_RATIO_LIMIT))
        );
        config.poolStableTokenRatioLimit = app.getUintValue(
            keccak256(abi.encode(key, stakeToken, POOL_STABLE_TOKEN_RATIO_LIMIT))
        );
        config.poolStableTokenLossLimit = app.getUintValue(
            keccak256(abi.encode(key, stakeToken, POOL_STABLE_TOKEN_LOSS_LIMIT))
        );
        config.assetTokens = app.getAddressArrayValues(keccak256(abi.encode(key, stakeToken, ASSET_TOKENS)));
        return config;
    }

    function setLpPoolConfig(address stakeToken, LpPoolConfig memory config) external {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = AppStorage.LP_POOL_CONFIG;
        app.addAddress(key, stakeToken);
        app.setUintValue(keccak256(abi.encode(key, stakeToken, BASE_INTEREST_RATE)), config.baseInterestRate);
        app.setUintValue(keccak256(abi.encode(key, stakeToken, POOL_LIQUIDITY_LIMIT)), config.poolLiquidityLimit);
        app.setUintValue(keccak256(abi.encode(key, stakeToken, MINT_FEE_RATE)), config.mintFeeRate);
        app.setUintValue(keccak256(abi.encode(key, stakeToken, REDEEM_FEE_RATE)), config.redeemFeeRate);
        app.setUintValue(keccak256(abi.encode(key, stakeToken, POOL_PNL_RATIO_LIMIT)), config.poolPnlRatioLimit);
        app.setUintValue(
            keccak256(abi.encode(key, stakeToken, UNSETTLED_BASE_TOKEN_RATIO_LIMIT)),
            config.unsettledBaseTokenRatioLimit
        );
        app.setUintValue(
            keccak256(abi.encode(key, stakeToken, UNSETTLED_STABLE_TOKEN_RATIO_LIMIT)),
            config.unsettledStableTokenRatioLimit
        );
        app.setUintValue(
            keccak256(abi.encode(key, stakeToken, POOL_STABLE_TOKEN_RATIO_LIMIT)),
            config.poolStableTokenRatioLimit
        );
        app.setUintValue(
            keccak256(abi.encode(key, stakeToken, POOL_STABLE_TOKEN_LOSS_LIMIT)),
            config.poolStableTokenLossLimit
        );
        app.setAddressArrayValues(keccak256(abi.encode(key, stakeToken, ASSET_TOKENS)), config.assetTokens);
    }

    function getStableTokenBorrowingInterestRate(address stableToken) external view returns (uint256) {
        AppStorage.Props storage app = AppStorage.load();
        return
            app.getUintValue(
                keccak256(abi.encode(AppStorage.USD_POOL_CONFIG, stableToken, STABLE_TOKENS_BORROWING_INTEREST_RATE))
            );
    }
}
