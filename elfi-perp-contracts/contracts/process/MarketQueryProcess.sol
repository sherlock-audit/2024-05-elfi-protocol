// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IMarket.sol";
import "../storage/Market.sol";
import "../storage/AppTradeConfig.sol";
import "./OracleProcess.sol";
import "./LpPoolQueryProcess.sol";

library MarketQueryProcess {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using Math for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using LpPoolQueryProcess for LpPool.Props;
    using LpPoolQueryProcess for UsdPool.Props;
    using UsdPool for UsdPool.Props;
    using Market for Market.Props;
    using Symbol for Symbol.Props;
    using CommonData for CommonData.Props;

    struct UpdateFundingCache {
        uint256 totalLongOpenInterest;
        uint256 totalShortOpenInterest;
        uint256 fundingFeeDurationInSecond;
        uint256 fundingRatePerSecond;
        uint256 totalFundingFee;
        uint256 currentLongFundingFeePerQty;
        uint256 currentShortFundingFeePerQty;
        int256 longFundingFeePerQtyDelta;
        int256 shortFundingFeePerQtyDelta;
        bool longPayShort;
    }

    function getMarketInfo(
        bytes32 symbol,
        OracleProcess.OracleParam[] calldata oracles
    ) external view returns (IMarket.MarketInfo memory) {
        Symbol.Props storage symbolProps = Symbol.load(symbol);
        if (!symbolProps.isExists()) {
            IMarket.MarketInfo memory result;
            return result;
        }
        LpPool.Props storage pool = LpPool.load(symbolProps.stakeToken);
        uint256 availableLiquidity = pool.getPoolAvailableLiquidity(oracles);
        Market.Props storage market = Market.load(symbol);
        uint256 longPositionInterest = market.longPosition.openInterest;
        uint256 totalShortPositionInterest = market.getAllShortOpenInterest();
        return
            IMarket.MarketInfo(
                symbolProps,
                longPositionInterest,
                market.longPosition.entryPrice,
                totalShortPositionInterest,
                market.getAllShortPositions(),
                availableLiquidity,
                market.fundingFee
            );
    }

    function getTradeTokenInfo(address token) external view returns (IMarket.TradeTokenInfo memory) {
        CommonData.Props storage commonData = CommonData.load();
        return
            IMarket.TradeTokenInfo(commonData.getTradeTokenCollateral(token), commonData.getTradeTokenLiability(token));
    }

    function getCumulativeBorrowingFeePerToken(
        address stakeToken,
        bool isLong,
        address marginToken
    ) external view returns (uint256) {
        if (isLong) {
            LpPool.Props storage pool = LpPool.load(stakeToken);
            return pool.borrowingFee.cumulativeBorrowingFeePerToken;
        } else {
            UsdPool.Props storage usdPool = UsdPool.load();
            return usdPool.getBorrowingFees(marginToken).cumulativeBorrowingFeePerToken;
        }
    }

    function getLongBorrowingRatePerSecond(LpPool.Props storage pool) external view returns (uint256) {
        if (pool.baseTokenBalance.amount == 0 && pool.baseTokenBalance.unsettledAmount == 0) {
            return 0;
        }
        int256 totalAmount = pool.baseTokenBalance.amount.toInt256() + pool.baseTokenBalance.unsettledAmount;
        if (totalAmount <= 0) {
            return 0;
        }
        uint256 holdRate = CalUtils.divToPrecision(
            pool.baseTokenBalance.holdAmount,
            totalAmount.toUint256(),
            CalUtils.SMALL_RATE_PRECISION
        );
        return CalUtils.mulSmallRate(holdRate, AppPoolConfig.getLpPoolConfig(pool.stakeToken).baseInterestRate);
    }

    function getShortBorrowingRatePerSecond(UsdPool.Props storage pool, address token) external view returns (uint256) {
        if (pool.getStableTokenBalance(token).amount == 0 && pool.getStableTokenBalance(token).unsettledAmount == 0) {
            return 0;
        }
        uint256 holdRate = CalUtils.divToPrecision(
            pool.getStableTokenBalance(token).holdAmount,
            (pool.getStableTokenBalance(token).amount + pool.getStableTokenBalance(token).unsettledAmount),
            CalUtils.SMALL_RATE_PRECISION
        );
        return CalUtils.mulSmallRate(holdRate, AppPoolConfig.getStableTokenBorrowingInterestRate(token));
    }

    function getUpdateMarketFundingFeeRate(
        bytes32 symbol
    ) external view returns (bool onlyUpdateTime, UpdateFundingCache memory) {
        UpdateFundingCache memory cache;
        Market.Props storage market = Market.load(symbol);
        Symbol.Props storage symbolProps = Symbol.load(symbol);
        cache.totalLongOpenInterest = market.getLongOpenInterest();
        cache.totalShortOpenInterest = market.getAllShortOpenInterest();
        if (
            (cache.totalLongOpenInterest == 0 && cache.totalShortOpenInterest == 0) ||
            cache.totalLongOpenInterest == cache.totalShortOpenInterest
        ) {
            return (true, cache);
        }
        cache.fundingFeeDurationInSecond = _getFundingFeeDurations(market);
        if (cache.fundingFeeDurationInSecond == 0) {
            return (true, cache);
        }
        cache.longPayShort = cache.totalLongOpenInterest > cache.totalShortOpenInterest;
        cache.fundingRatePerSecond = _getFundingRatePerSecond(market);
        cache.totalFundingFee = Math
            .max(cache.totalLongOpenInterest, cache.totalShortOpenInterest)
            .mul(cache.fundingFeeDurationInSecond)
            .mul(cache.fundingRatePerSecond);
        if (cache.totalLongOpenInterest > 0) {
            cache.currentLongFundingFeePerQty = cache.longPayShort
                ? cache.totalFundingFee.div(cache.totalLongOpenInterest)
                : _boundFundingFeePerQty(
                    cache.totalFundingFee.div(cache.totalLongOpenInterest),
                    cache.fundingFeeDurationInSecond
                );
            cache.longFundingFeePerQtyDelta = CalUtils
                .usdToToken(
                    cache.currentLongFundingFeePerQty,
                    TokenUtils.decimals(symbolProps.baseToken),
                    OracleProcess.getLatestUsdUintPrice(symbolProps.baseToken, true)
                )
                .toInt256();
            cache.longFundingFeePerQtyDelta = cache.longPayShort
                ? cache.longFundingFeePerQtyDelta
                : -cache.longFundingFeePerQtyDelta;
        }
        if (cache.totalShortOpenInterest > 0) {
            cache.shortFundingFeePerQtyDelta = cache.longPayShort
                ? -_boundFundingFeePerQty(
                    cache.totalFundingFee.div(cache.totalShortOpenInterest),
                    cache.fundingFeeDurationInSecond
                ).toInt256()
                : (cache.totalFundingFee.div(cache.totalShortOpenInterest)).toInt256();
        }
        return (false, cache);
    }

    function getFundingFeePerQty(bytes32 symbol, bool isLong) external view returns (int256) {
        Market.Props storage market = Market.load(symbol);
        return isLong ? market.fundingFee.longFundingFeePerQty : market.fundingFee.shortFundingFeePerQty;
    }

    function _getFundingRatePerSecond(Market.Props storage market) internal view returns (uint256) {
        uint256 longPositionInterest = market.longPosition.openInterest;
        uint256 totalShortPositionInterest = market.getAllShortOpenInterest();
        uint256 diffOpenInterest = CalUtils.diff(longPositionInterest, totalShortPositionInterest);
        uint256 totalOpenInterest = longPositionInterest + totalShortPositionInterest;
        if (diffOpenInterest == 0 || totalOpenInterest == 0) {
            return 0;
        }
        return Math.mulDiv(diffOpenInterest, AppTradeConfig.getTradeConfig().fundingFeeBaseRate, totalOpenInterest);
    }

    function _getFundingFeeDurations(Market.Props storage market) internal view returns (uint256) {
        if (market.fundingFee.lastUpdateTime == 0) {
            return 0;
        }
        return ChainUtils.currentTimestamp() - market.fundingFee.lastUpdateTime;
    }

    function _boundFundingFeePerQty(
        uint256 currentFundingFeePerQty,
        uint256 durationInSecond
    ) internal view returns (uint256) {
        return AppTradeConfig.getTradeConfig().maxFundingBaseRate.mul(durationInSecond).min(currentFundingFeePerQty);
    }
}
