// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../storage/Account.sol";
import "./OracleProcess.sol";
import "./PositionQueryProcess.sol";

library AccountProcess {
    using SafeERC20 for IERC20;
    using Account for Account.Props;
    using PositionQueryProcess for Position.Props;
    using Position for Position.Props;
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedMath for int256;
    using SignedSafeMath for int256;

    function getCrossMMR(
        Account.Props storage accountProps,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (int256, int256, uint256) {
        uint256 portfolioNetValue = getPortfolioNetValue(accountProps, oracles);
        uint256 totalUsedValue = getTotalUsedValue(accountProps, oracles);
        PositionQueryProcess.PositionStaticsCache memory cache = PositionQueryProcess.getAccountAllCrossPositionValue(
            accountProps,
            oracles
        );
        int256 crossNetValue = _getCrossNetValue(cache, portfolioNetValue, totalUsedValue, accountProps.orderHoldInUsd);
        if (cache.totalMM <= 0) {
            return (0, crossNetValue, cache.totalMM);
        }
        return (
            crossNetValue <= 0
                ? int256(0)
                : CalUtils.divToPrecision(crossNetValue.toUint256(), cache.totalMM, CalUtils.RATE_PRECISION).toInt256(),
            crossNetValue,
            cache.totalMM
        );
    }

    function isCrossLiquidation(Account.Props storage accountProps) external view returns (bool) {
        OracleProcess.OracleParam[] memory oracles;
        (, int256 crossNetValue, uint256 totalMM) = getCrossMMR(accountProps, oracles);
        return crossNetValue <= 0 || crossNetValue.toUint256() <= totalMM;
    }

    function getPortfolioNetValue(Account.Props storage accountProps) public view returns (uint256) {
        OracleProcess.OracleParam[] memory oracles;
        return getPortfolioNetValue(accountProps, oracles);
    }

    function getPortfolioNetValue(
        Account.Props storage accountProps,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (uint256) {
        uint256 totalNetValue;
        address[] memory tokens = accountProps.getTokens();
        for (uint256 i; i < tokens.length; i++) {
            if (!AppTradeTokenConfig.getTradeTokenConfig(tokens[i]).isSupportCollateral) {
                continue;
            }
            Account.TokenBalance memory tokenBalance = accountProps.tokenBalances[tokens[i]];
            totalNetValue = totalNetValue.add(_getTokenNetValue(tokens[i], tokenBalance, oracles));
        }
        return totalNetValue;
    }

    function getTotalUsedValue(Account.Props storage accountProps) public view returns (uint256) {
        OracleProcess.OracleParam[] memory oracles;
        return getTotalUsedValue(accountProps, oracles);
    }

    function getTotalUsedValue(
        Account.Props storage accountProps,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (uint256) {
        uint256 totalUsedValue;
        address[] memory tokens = accountProps.getTokens();
        for (uint256 i; i < tokens.length; i++) {
            Account.TokenBalance memory tokenBalance = accountProps.tokenBalances[tokens[i]];
            totalUsedValue = totalUsedValue.add(_getTokenUsedValue(tokens[i], tokenBalance, oracles));
        }
        if (accountProps.orderHoldInUsd > 0) {
            totalUsedValue += accountProps.orderHoldInUsd;
        }
        return totalUsedValue;
    }

    function getCrossUsedValueAndBorrowingValue(
        Account.Props storage accountProps,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (uint256, uint256) {
        uint256 totalUsedValue;
        uint256 totalBorrowingValue;
        address[] memory tokens = accountProps.getTokens();
        for (uint256 i; i < tokens.length; i++) {
            Account.TokenBalance memory tokenBalance = accountProps.tokenBalances[tokens[i]];
            totalUsedValue = totalUsedValue.add(_getTokenUsedValue(tokens[i], tokenBalance, oracles));
            totalBorrowingValue = totalBorrowingValue.add(_getTokenBorrowingValue(tokens[i], tokenBalance, oracles));
        }
        if (accountProps.orderHoldInUsd > 0) {
            totalUsedValue += accountProps.orderHoldInUsd;
            totalBorrowingValue += accountProps.orderHoldInUsd;
        }
        return (totalUsedValue, totalBorrowingValue);
    }

    function getCrossNetValueAndTotalQty(
        Account.Props storage accountProps
    ) public view returns (int256 crossNetValue, int256 totalQty) {
        uint256 portfolioNetValue = getPortfolioNetValue(accountProps);
        uint256 totalUsedValue = getTotalUsedValue(accountProps);
        PositionQueryProcess.PositionStaticsCache memory cache = PositionQueryProcess.getAccountAllCrossPositionValue(
            accountProps
        );
        crossNetValue = _getCrossNetValue(cache, portfolioNetValue, totalUsedValue, accountProps.orderHoldInUsd);
        totalQty = cache.totalQty.toInt256();
    }

    function getCrossAvailableValue(Account.Props storage accountProps) public view returns (int256) {
        OracleProcess.OracleParam[] memory oracles;
        return getCrossAvailableValue(accountProps, oracles);
    }

    function getCrossAvailableValue(
        Account.Props storage accountProps,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (int256) {
        uint256 totalNetValue = getPortfolioNetValue(accountProps, oracles);
        (uint256 totalUsedValue, uint256 totalBorrowingValue) = getCrossUsedValueAndBorrowingValue(
            accountProps,
            oracles
        );

        PositionQueryProcess.PositionStaticsCache memory cache = PositionQueryProcess.getAccountAllCrossPositionValue(
            accountProps,
            oracles
        );

        return
            (totalNetValue + cache.totalIMUsd + accountProps.orderHoldInUsd).toInt256() -
            totalUsedValue.toInt256() +
            (cache.totalPnl >= 0 ? int256(0) : cache.totalPnl) -
            (cache.totalIMUsdFromBalance + totalBorrowingValue).toInt256();
    }

    function _getCrossNetValue(
        PositionQueryProcess.PositionStaticsCache memory cache,
        uint256 portfolioNetValue,
        uint256 totalUsedValue,
        uint256 orderHoldUsd
    ) internal pure returns (int256) {
        return
            (portfolioNetValue + cache.totalIMUsd + orderHoldUsd).toInt256() +
            cache.totalPnl -
            totalUsedValue.toInt256() -
            cache.totalPosFee;
    }

    function _getTokenNetValue(
        address token,
        Account.TokenBalance memory tokenBalance,
        OracleProcess.OracleParam[] memory oracles
    ) internal view returns (uint256) {
        if (tokenBalance.amount <= tokenBalance.usedAmount) {
            return 0;
        }
        uint256 tokenValue = CalUtils.tokenToUsd(
            tokenBalance.amount - tokenBalance.usedAmount,
            TokenUtils.decimals(token),
            OracleProcess.getOraclePrices(oracles, token, true)
        );
        return CalUtils.mulRate(tokenValue, AppTradeTokenConfig.getTradeTokenConfig(token).discount);
    }

    function _getTokenUsedValue(
        address token,
        Account.TokenBalance memory tokenBalance,
        OracleProcess.OracleParam[] memory oracles
    ) internal view returns (uint256) {
        if (tokenBalance.usedAmount <= tokenBalance.amount) {
            return 0;
        }
        uint256 tokenUsedValue = CalUtils.tokenToUsd(
            tokenBalance.usedAmount - tokenBalance.amount,
            TokenUtils.decimals(token),
            OracleProcess.getOraclePrices(oracles, token, true)
        );
        if (AppTradeTokenConfig.getTradeTokenConfig(token).liquidationFactor > 0) {
            return
                tokenUsedValue +
                CalUtils.mulRate(tokenUsedValue, AppTradeTokenConfig.getTradeTokenConfig(token).liquidationFactor);
        } else {
            return tokenUsedValue;
        }
    }

    function _getTokenBorrowingValue(
        address token,
        Account.TokenBalance memory tokenBalance,
        OracleProcess.OracleParam[] memory oracles
    ) internal view returns (uint256) {
        if (tokenBalance.usedAmount - tokenBalance.liability <= tokenBalance.amount) {
            return 0;
        }
        return
            CalUtils.tokenToUsd(
                tokenBalance.usedAmount - tokenBalance.liability - tokenBalance.amount,
                TokenUtils.decimals(token),
                OracleProcess.getOraclePrices(oracles, token, true)
            );
    }
}
