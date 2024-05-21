// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../storage/AppConfig.sol";
import "./MarketQueryProcess.sol";

/// @title MarketProcess
/// @dev Library to handle market functions 
library MarketProcess {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using Math for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using Market for Market.Props;
    using MarketQueryProcess for Market.Props;
    using UsdPool for UsdPool.Props;
    using LpPool for LpPool.Props;

    event MarketOIUpdateEvent(bytes32 symbol, bool isLong, uint256 preOpenInterest, uint256 openInterest);

    /// @dev Parameters for updating open interest (OI).
    /// @param isAdd Indicates if the OI is being added or subtracted.
    /// @param symbol The market symbol.
    /// @param token The token address.
    /// @param qty The changed quantity.
    /// @param entryPrice The entry price.
    /// @param isLong Indicates if the position is long or short.
    struct UpdateOIParams {
        bool isAdd;
        bytes32 symbol;
        address token;
        uint256 qty;
        uint256 entryPrice;
        bool isLong;
    }

    /// @dev Updates the market funding fee rate.
    /// @param symbol The market symbol.
    function updateMarketFundingFeeRate(bytes32 symbol) external {
        (bool onlyUpdateTime, MarketQueryProcess.UpdateFundingCache memory cache) = MarketQueryProcess
            .getUpdateMarketFundingFeeRate(symbol);
        Market.Props storage market = Market.load(symbol);
        if (onlyUpdateTime) {
            market.fundingFee.lastUpdateTime = ChainUtils.currentTimestamp();
            market.emitFundingFeeEvent();
            return;
        }
        market.fundingFee.longFundingFeeRate = cache
            .longFundingFeePerQtyDelta
            .mul(int256(3600))
            .div(cache.fundingFeeDurationInSecond.toInt256())
            .div(10 ** 13);
        market.fundingFee.shortFundingFeeRate = cache
            .shortFundingFeePerQtyDelta
            .mul(int256(3600))
            .div(cache.fundingFeeDurationInSecond.toInt256())
            .div(10 ** 13);
        market.fundingFee.longFundingFeePerQty += cache.longFundingFeePerQtyDelta;
        market.fundingFee.shortFundingFeePerQty += cache.shortFundingFeePerQtyDelta;
        market.fundingFee.lastUpdateTime = ChainUtils.currentTimestamp();
        market.emitFundingFeeEvent();
    }

    /// @dev Updates the pool borrowing fee rate.
    /// @param stakeToken The address of the pool.
    /// @param isLong Indicates if the position is long or short.
    /// @param marginToken The margin token address.
    function updatePoolBorrowingFeeRate(address stakeToken, bool isLong, address marginToken) external {
        if (isLong) {
            LpPool.Props storage pool = LpPool.load(stakeToken);
            uint256 borrowingFeeDurationInSecond = _getFeeDurations(pool.borrowingFee.lastUpdateTime);
            pool.borrowingFee.cumulativeBorrowingFeePerToken += MarketQueryProcess
                .getLongBorrowingRatePerSecond(pool)
                .mul(borrowingFeeDurationInSecond);
            pool.borrowingFee.lastUpdateTime = ChainUtils.currentTimestamp();
            pool.emitPoolBorrowingFeeUpdateEvent();
        } else {
            UsdPool.Props storage usdPool = UsdPool.load();
            UsdPool.BorrowingFee storage borrowingFees = usdPool.getBorrowingFees(marginToken);
            uint256 borrowingFeeDurationInSecond = _getFeeDurations(borrowingFees.lastUpdateTime);
            borrowingFees.cumulativeBorrowingFeePerToken += MarketQueryProcess
                .getShortBorrowingRatePerSecond(usdPool, marginToken)
                .mul(borrowingFeeDurationInSecond);
            borrowingFees.lastUpdateTime = ChainUtils.currentTimestamp();
            usdPool.emitPoolBorrowingFeeUpdateEvent(marginToken);
        }
    }

    /// @dev Updates the total borrowing fee.
    /// @param stakeToken The address of the pool.
    /// @param isLong Indicates if the position is long or short.
    /// @param marginToken The margin token address.
    /// @param borrowingFee The changed borrowing fee.
    /// @param realizedBorrowingFee The realized borrowing fee.
    function updateTotalBorrowingFee(
        address stakeToken,
        bool isLong,
        address marginToken,
        int256 borrowingFee,
        int256 realizedBorrowingFee
    ) external {
        if (isLong) {
            LpPool.Props storage pool = LpPool.load(stakeToken);
            pool.borrowingFee.totalBorrowingFee = borrowingFee > 0
                ? (pool.borrowingFee.totalBorrowingFee + borrowingFee.toUint256())
                : (pool.borrowingFee.totalBorrowingFee - (-borrowingFee).toUint256());
            pool.borrowingFee.totalRealizedBorrowingFee = realizedBorrowingFee > 0
                ? (pool.borrowingFee.totalRealizedBorrowingFee + realizedBorrowingFee.toUint256())
                : (pool.borrowingFee.totalRealizedBorrowingFee - (-realizedBorrowingFee).toUint256());
            pool.emitPoolBorrowingFeeUpdateEvent();
        } else {
            UsdPool.Props storage usdPool = UsdPool.load();
            UsdPool.BorrowingFee storage borrowingFees = usdPool.getBorrowingFees(marginToken);
            borrowingFees.totalBorrowingFee = borrowingFee > 0
                ? (borrowingFees.totalBorrowingFee + borrowingFee.toUint256())
                : (borrowingFees.totalBorrowingFee - (-borrowingFee).toUint256());
            borrowingFees.totalRealizedBorrowingFee = realizedBorrowingFee > 0
                ? (borrowingFees.totalRealizedBorrowingFee + realizedBorrowingFee.toUint256())
                : (borrowingFees.totalRealizedBorrowingFee - (-realizedBorrowingFee).toUint256());
            usdPool.emitPoolBorrowingFeeUpdateEvent(marginToken);
        }
    }

    /// @dev Updates the market funding fee.
    /// @param symbol The market symbol.
    /// @param realizedFundingFeeDelta The delta of the realized funding fee.
    /// @param isLong Indicates if the position is long or short.
    /// @param needUpdateUnsettle Indicates if the unsettled amount needs to be updated.
    /// @param marginToken The margin token address.
    function updateMarketFundingFee(
        bytes32 symbol,
        int256 realizedFundingFeeDelta,
        bool isLong,
        bool needUpdateUnsettle,
        address marginToken
    ) external {
        Market.Props storage market = Market.load(symbol);
        if (isLong) {
            market.fundingFee.totalLongFundingFee += realizedFundingFeeDelta;
        } else {
            market.fundingFee.totalShortFundingFee += realizedFundingFeeDelta;
        }
        market.emitFundingFeeEvent();
        if (needUpdateUnsettle) {
            Symbol.Props storage symbolProps = Symbol.load(symbol);
            LpPool.Props storage pool = LpPool.load(symbolProps.stakeToken);
            if (isLong) {
                pool.addUnsettleBaseToken(realizedFundingFeeDelta);
            } else {
                pool.addUnsettleStableToken(marginToken, realizedFundingFeeDelta);
            }
        }
    }

    /// @notice Updates the market open interest (OI).
    /// @param params UpdateOIParams.
    function updateMarketOI(UpdateOIParams memory params) external {
        Market.Props storage market = Market.load(params.symbol);
        AppConfig.SymbolConfig memory symbolConfig = AppConfig.getSymbolConfig(params.symbol);
        if (params.isAdd && params.isLong) {
            _addOI(market.longPosition, params, symbolConfig.tickSize);
        } else if (params.isAdd && !params.isLong) {
            market.addShortToken(params.token);
            _addOI(market.shortPositionMap[params.token], params, symbolConfig.tickSize);
        } else if (!params.isAdd) {
            _subOI(params.isLong ? market.longPosition : market.shortPositionMap[params.token], params);
        }

        if (params.isAdd) {
            uint256 longOpenInterest = market.getLongOpenInterest();
            uint256 shortOpenInterest = market.getAllShortOpenInterest();
            if (params.isLong && longOpenInterest > symbolConfig.maxLongOpenInterestCap) {
                revert Errors.MaxOILimited(params.symbol, params.isLong);
            }
            if (!params.isLong && shortOpenInterest > symbolConfig.maxShortOpenInterestCap) {
                revert Errors.MaxOILimited(params.symbol, params.isLong);
            }
            uint256 minOpenInterest = longOpenInterest.min(shortOpenInterest);
            if (minOpenInterest < symbolConfig.longShortOiBottomLimit) {
                return;
            }
            if (
                longOpenInterest.max(shortOpenInterest) - minOpenInterest >
                CalUtils.mulRate(longOpenInterest + shortOpenInterest, symbolConfig.longShortRatioLimit)
            ) {
                revert Errors.OIRatioLimited();
            }
        }
    }

    /// @dev Calculates the duration since the last fee update.
    /// @param lastUpdateTime The timestamp of the last update.
    /// @return The duration in seconds since the last update.
    function _getFeeDurations(uint256 lastUpdateTime) internal view returns (uint256) {
        if (lastUpdateTime == 0) {
            return 0;
        }
        return ChainUtils.currentTimestamp() - lastUpdateTime;
    }

    /// @dev Updates the market position's entry price and open interest.
    /// @param position Market.MarketPosition.
    /// @param params UpdateOIParams.
    /// @param tickSize The tick size used for calculating the average entry price.
    function _addOI(Market.MarketPosition storage position, UpdateOIParams memory params, uint256 tickSize) internal {
        if (position.openInterest == 0) {
            position.entryPrice = params.entryPrice;
            position.openInterest = params.qty;
        } else {
            position.entryPrice = CalUtils.computeAvgEntryPrice(
                position.openInterest,
                position.entryPrice,
                params.qty,
                params.entryPrice,
                tickSize,
                params.isLong
            );
            position.openInterest += params.qty;
        }
        emit MarketOIUpdateEvent(
            params.symbol,
            params.isLong,
            position.openInterest - params.qty,
            position.openInterest
        );
    }

    /// @dev Updates the market position's entry price and open interest.
    /// @param position Market.MarketPosition.
    /// @param params UpdateOIParams.
    function _subOI(Market.MarketPosition storage position, UpdateOIParams memory params) internal {
        if (position.openInterest <= params.qty) {
            position.entryPrice = 0;
            position.openInterest = 0;
        } else {
            position.openInterest -= params.qty;
        }
        emit MarketOIUpdateEvent(
            params.symbol,
            params.isLong,
            position.openInterest + params.qty,
            position.openInterest
        );
    }
}
