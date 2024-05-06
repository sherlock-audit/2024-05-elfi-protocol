// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../storage/AppConfig.sol";
import "./MarketQueryProcess.sol";

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

    struct UpdateOIParams {
        bool isAdd;
        bytes32 symbol;
        address token;
        uint256 qty;
        uint256 entryPrice;
        bool isLong;
    }

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

    function _getFeeDurations(uint256 lastUpdateTime) internal view returns (uint256) {
        if (lastUpdateTime == 0) {
            return 0;
        }
        return ChainUtils.currentTimestamp() - lastUpdateTime;
    }

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
