// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";

import "../storage/Position.sol";
import "../storage/Account.sol";
import "../storage/AppConfig.sol";
import "./MarketQueryProcess.sol";

library PositionQueryProcess {
    using Math for uint256;
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SignedSafeMath for int256;
    using SafeCast for int256;
    using Account for Account.Props;
    using UsdPool for UsdPool.Props;

    struct ComputePositionFeeCache {
        int256 posFundingFeeInUsd;
        uint256 posBorrowingFeeInUsd;
        uint8 tokenDecimal;
        int256 fundingFeePerQty;
        int256 unRealizedFundingFeeDelta;
        uint256 cumulativeBorrowingFeePerToken;
        uint256 unRealizedBorrowingFeeDelta;
    }

    struct PositionStaticsCache {
        int256 totalPnl;
        uint256 totalIMUsd;
        uint256 totalIMUsdFromBalance;
        uint256 totalMM;
        int256 totalPosFee;
        uint256 totalQty;
    }

    function hasOtherShortPosition(
        address account,
        bytes32 symbol,
        address marginToken,
        bool isCrossMargin
    ) external view returns (bool) {
        address[] memory stableTokens = UsdPool.getSupportedStableTokens();
        for (uint256 i; i < stableTokens.length; i++) {
            if (stableTokens[i] == marginToken) {
                continue;
            }
            Position.Props storage position = Position.load(account, symbol, stableTokens[i], isCrossMargin);
            if (position.qty > 0) {
                return true;
            }
        }
        return false;
    }

    function getPositionUnPnl(
        Position.Props memory position,
        int256 computeIndexPrice,
        bool pnlToken
    ) public view returns (int256) {
        OracleProcess.OracleParam[] memory oracles;
        return getPositionUnPnl(position, oracles, computeIndexPrice, pnlToken);
    }

    function getPositionUnPnl(
        Position.Props memory position,
        OracleProcess.OracleParam[] memory oracles,
        int256 computeIndexPrice,
        bool pnlToken
    ) public view returns (int256) {
        (int256 pnlInToken, int256 pnlInUsd) = getPositionUnPnl(position, oracles, computeIndexPrice);
        return pnlToken ? pnlInToken : pnlInUsd;
    }

    function getPositionUnPnl(
        Position.Props memory position,
        OracleProcess.OracleParam[] memory oracles,
        int256 computeIndexPrice
    ) public view returns (int256, int256) {
        if (position.qty == 0) {
            return (0, 0);
        }
        if (position.isLong) {
            int pnlInUsd = position.qty.toInt256().mul(computeIndexPrice.sub(position.entryPrice.toInt256())).div(
                position.entryPrice.toInt256()
            );
            return (
                CalUtils.usdToTokenInt(pnlInUsd, TokenUtils.decimals(position.marginToken), computeIndexPrice),
                pnlInUsd
            );
        } else {
            int pnlInUsd = position.qty.toInt256().mul(position.entryPrice.toInt256().sub(computeIndexPrice)).div(
                position.entryPrice.toInt256()
            );
            int256 marginTokenPrice = OracleProcess.getIntOraclePrices(oracles, position.marginToken, false);
            return (
                CalUtils.usdToTokenInt(pnlInUsd, TokenUtils.decimals(position.marginToken), marginTokenPrice),
                pnlInUsd
            );
        }
    }

    function getLiquidationPrice(Position.Props storage position) external view returns (uint256) {
        AppConfig.SymbolConfig memory symbolConfig = AppConfig.getSymbolConfig(position.symbol);
        uint256 mmInUsd = getMM(
            position.qty,
            symbolConfig.maxLeverage,
            AppTradeConfig.getTradeConfig().maxMaintenanceMarginRate
        );
        int256 posFee = getPositionFee(position);
        int256 positionValue = position.isLong
            ? (position.qty - position.initialMarginInUsd + mmInUsd).toInt256() + posFee
            : (position.qty + position.initialMarginInUsd - mmInUsd).toInt256() - posFee;
        if (positionValue < 0) {
            return 0;
        }
        uint256 liquidationPrice = positionValue.toUint256().mul(position.entryPrice).div(position.qty);
        return CalUtils.formatToTickSize(liquidationPrice, symbolConfig.tickSize, position.isLong);
    }

    function getPositionMMRate(Position.Props memory position) public view returns (uint256) {
        AppConfig.SymbolConfig memory symbolConfig = AppConfig.getSymbolConfig(position.symbol);
        return
            CalUtils.divRate(CalUtils.RATE_PRECISION, symbolConfig.maxLeverage.mul(2)).min(
                AppTradeConfig.getTradeConfig().maxMaintenanceMarginRate
            );
    }

    function getMM(uint256 qty, uint256 leverage, uint256 maxMMRate) public pure returns (uint256) {
        return CalUtils.divRate(qty, leverage.mul(2)).min(CalUtils.mulRate(qty, maxMMRate));
    }

    function getPositionMM(Position.Props memory position) public view returns (uint256) {
        AppConfig.SymbolConfig memory symbolConfig = AppConfig.getSymbolConfig(position.symbol);
        uint256 maxMaintenanceMarginRate = AppTradeConfig.getTradeConfig().maxMaintenanceMarginRate;
        return getMM(position.qty, symbolConfig.maxLeverage, maxMaintenanceMarginRate);
    }

    function getAllPosition(
        Account.Props storage accountProps,
        bool isCrossMargin
    ) public view returns (Position.Props[] memory) {
        bytes32[] memory positionKeys = accountProps.getAllPosition();
        Position.Props[] memory positions = new Position.Props[](_getPositionIndex(positionKeys, isCrossMargin));
        uint256 positionIndex;
        for (uint256 i; i < positionKeys.length; i++) {
            Position.Props memory position = Position.load(positionKeys[i]);
            if (position.isCrossMargin == isCrossMargin) {
                positions[positionIndex] = position;
                positionIndex += 1;
            }
        }
        return positions;
    }

    function getUnRealisedBorrowingFee(Position.Props storage position) external view returns (uint256) {
        uint256 cumulativeBorrowingFeePerToken;
        if (position.isLong) {
            LpPool.Props storage pool = LpPool.load(Symbol.load(position.symbol).stakeToken);
            uint256 borrowingFeeDurationInSecond = _getFeeDurations(pool.borrowingFee.lastUpdateTime);
            cumulativeBorrowingFeePerToken =
                pool.borrowingFee.cumulativeBorrowingFeePerToken +
                MarketQueryProcess.getLongBorrowingRatePerSecond(pool).mul(borrowingFeeDurationInSecond);
        } else {
            UsdPool.Props storage usdPool = UsdPool.load();
            UsdPool.BorrowingFee storage borrowingFees = usdPool.getBorrowingFees(position.marginToken);
            uint256 borrowingFeeDurationInSecond = _getFeeDurations(borrowingFees.lastUpdateTime);
            cumulativeBorrowingFeePerToken =
                borrowingFees.cumulativeBorrowingFeePerToken +
                MarketQueryProcess.getShortBorrowingRatePerSecond(usdPool, position.marginToken).mul(
                    borrowingFeeDurationInSecond
                );
        }
        return
            CalUtils.mulSmallRate(
                CalUtils.mulRate(position.initialMargin, position.leverage - CalUtils.RATE_PRECISION),
                cumulativeBorrowingFeePerToken - position.positionFee.openBorrowingFeePerToken
            );
    }

    function getUnRealisedFundingFee(Position.Props storage position) external view returns (int256) {
        (, MarketQueryProcess.UpdateFundingCache memory cache) = MarketQueryProcess.getUpdateMarketFundingFeeRate(
            position.symbol
        );
        Market.Props storage market = Market.load(position.symbol);
        int256 fundingFeePerQty = position.isLong
            ? market.fundingFee.longFundingFeePerQty + cache.longFundingFeePerQtyDelta
            : market.fundingFee.shortFundingFeePerQty + cache.shortFundingFeePerQtyDelta;
        return
            CalUtils.mulIntSmallRate(
                position.qty.toInt256(),
                (fundingFeePerQty - position.positionFee.openFundingFeePerQty)
            );
    }

    function getPositionFee(Position.Props memory position) public view returns (int256) {
        OracleProcess.OracleParam[] memory oracles;
        return getPositionFee(position, oracles);
    }

    function getPositionFee(
        Position.Props memory position,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (int256) {
        ComputePositionFeeCache memory cache;
        cache.fundingFeePerQty = MarketQueryProcess.getFundingFeePerQty(position.symbol, position.isLong);
        cache.unRealizedFundingFeeDelta = CalUtils.mulIntSmallRate(
            position.qty.toInt256(),
            (cache.fundingFeePerQty - position.positionFee.openFundingFeePerQty)
        );
        cache.tokenDecimal = TokenUtils.decimals(position.marginToken);
        if (position.isLong) {
            cache.posFundingFeeInUsd =
                position.positionFee.realizedFundingFeeInUsd +
                CalUtils.tokenToUsdInt(
                    cache.unRealizedFundingFeeDelta,
                    cache.tokenDecimal,
                    OracleProcess.getIntOraclePrices(oracles, position.marginToken, position.isLong)
                );
        } else {
            cache.posFundingFeeInUsd = position.positionFee.realizedFundingFeeInUsd + cache.unRealizedFundingFeeDelta;
        }

        Symbol.Props memory symbolProps = Symbol.load(position.symbol);
        cache.cumulativeBorrowingFeePerToken = MarketQueryProcess.getCumulativeBorrowingFeePerToken(
            symbolProps.stakeToken,
            position.isLong,
            position.marginToken
        );
        cache.unRealizedBorrowingFeeDelta = CalUtils.mulSmallRate(
            CalUtils.mulRate(position.initialMargin, position.leverage - CalUtils.RATE_PRECISION),
            cache.cumulativeBorrowingFeePerToken - position.positionFee.openBorrowingFeePerToken
        );

        cache.posBorrowingFeeInUsd =
            position.positionFee.realizedBorrowingFeeInUsd +
            CalUtils.tokenToUsd(
                cache.unRealizedBorrowingFeeDelta,
                cache.tokenDecimal,
                OracleProcess.getOraclePrices(oracles, position.marginToken, position.isLong)
            );
        return
            position.positionFee.closeFeeInUsd.toInt256() +
            cache.posFundingFeeInUsd +
            cache.posBorrowingFeeInUsd.toInt256();
    }

    function getAccountAllCrossPositionValue(
        Account.Props storage accountProps
    ) public view returns (PositionStaticsCache memory) {
        OracleProcess.OracleParam[] memory cache;
        return getAccountAllCrossPositionValue(accountProps, cache);
    }

    function getAccountAllCrossPositionValue(
        Account.Props storage accountProps,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (PositionStaticsCache memory cache) {
        accountProps.checkExists();
        Position.Props[] memory allCrossPositions = getAllPosition(accountProps, true);

        uint256 maxMaintenanceMarginRate = AppTradeConfig.getTradeConfig().maxMaintenanceMarginRate;
        for (uint256 i; i < allCrossPositions.length; i++) {
            Position.Props memory position = allCrossPositions[i];
            int256 indexTokenPrice = OracleProcess.getIntOraclePrices(oracles, position.indexToken, position.isLong);
            AppConfig.SymbolConfig memory symbolConfig = AppConfig.getSymbolConfig(position.symbol);
            int256 unPnl = getPositionUnPnl(position, oracles, indexTokenPrice, false);
            if (unPnl > 0) {
                cache.totalPnl = cache.totalPnl.add(
                    CalUtils.mulRate(
                        unPnl,
                        AppTradeTokenConfig.getTradeTokenConfig(position.marginToken).discount.toInt256()
                    )
                );
            } else {
                cache.totalPnl = cache.totalPnl.add(
                    CalUtils.mulRate(
                        unPnl,
                        (CalUtils.RATE_PRECISION +
                            AppTradeTokenConfig.getTradeTokenConfig(position.marginToken).liquidationFactor).toInt256()
                    )
                );
            }

            cache.totalMM = cache.totalMM.add(getMM(position.qty, symbolConfig.maxLeverage, maxMaintenanceMarginRate));
            cache.totalIMUsd = cache.totalIMUsd.add(position.initialMarginInUsd);
            cache.totalIMUsdFromBalance = cache.totalIMUsdFromBalance.add(position.initialMarginInUsdFromBalance);
            cache.totalQty = cache.totalQty.add(position.qty);
            cache.totalPosFee = cache.totalPosFee.add(getPositionFee(position, oracles));
        }
    }

    function _getPositionIndex(bytes32[] memory positionKeys, bool isCrossMargin) internal pure returns (uint256) {
        uint256 positionIndex;
        Position.Props memory position;
        for (uint256 i; i < positionKeys.length; i++) {
            position = Position.load(positionKeys[i]);
            if (position.isCrossMargin == isCrossMargin) {
                positionIndex += 1;
            }
        }

        return positionIndex;
    }

    function _getFeeDurations(uint256 lastUpdateTime) internal view returns (uint256) {
        if (lastUpdateTime == 0) {
            return 0;
        }
        return ChainUtils.currentTimestamp() - lastUpdateTime;
    }
}
