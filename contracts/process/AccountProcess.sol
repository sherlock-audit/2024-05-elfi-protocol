// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../storage/Account.sol";
import "./OracleProcess.sol";
import "./PositionQueryProcess.sol";

/// @title AccountProcess
/// @dev Library to get account info, only used for cross margin mode
/// 
/// portfolioNetValue: The net value of all collateral in the account, in USD.
/// totalUsedValue: The total used value in USD, including portions used for positions and orders. 
/// availableValue: The amount that can be used to increase positions or make withdrawals in USD.
/// orderHoldInUsd: The value held by the account's active orders, in USD
/// crossMMR: If the overall account risk ratio drops to 100%, it triggers the liquidation of all positions and collateral.
/// crossNetValue: In The account net value is composed of collateral, position margin, and position profit and loss, in USD.
/// totalMM: The total sum of all maintenance margins
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

    /// @dev Calculates the cross margin maintenance ratio (MMR) for an account
    /// @param accountProps Account.Props
    /// @param oracles OracleProcess.OracleParam[]
    /// @return (int256, int256, uint256) The cross MMR, cross net value, and total MMR
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

    /// @dev Checks if the cross positions needs to be liquidated.
    /// @param accountProps Account.Props
    /// @return bool True if the cross positions needs to be liquidated, false otherwise
    function isCrossLiquidation(Account.Props storage accountProps) external view returns (bool) {
        OracleProcess.OracleParam[] memory oracles;
        (, int256 crossNetValue, uint256 totalMM) = getCrossMMR(accountProps, oracles);
        return crossNetValue <= 0 || crossNetValue.toUint256() <= totalMM;
    }

    /// @dev Gets the account's portfolio net value
    /// @param accountProps Account.Props
    /// @return uint256 The net value of the portfolio
    function getPortfolioNetValue(Account.Props storage accountProps) public view returns (uint256) {
        OracleProcess.OracleParam[] memory oracles;
        return getPortfolioNetValue(accountProps, oracles);
    }

    /// @dev Gets the account's portfolio net value using oracle parameters
    /// @param accountProps Account.Props
    /// @param oracles OracleProcess.OracleParam[]
    /// @return uint256 The net value of the portfolio (in USD)
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

    /// @dev Gets the total used value of the account
    /// @param accountProps Account.Props
    /// @return uint256 The total used value
    function getTotalUsedValue(Account.Props storage accountProps) public view returns (uint256) {
        OracleProcess.OracleParam[] memory oracles;
        return getTotalUsedValue(accountProps, oracles);
    }

    /// @dev Gets the total used value of the account using oracle parameters
    /// @param accountProps Account.Props
    /// @param oracles OracleProcess.OracleParam[]
    /// @return uint256 The total used value (in USD)
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

    /// @dev Gets the cross used value and borrowing value of the account
    /// @param accountProps Account.Props
    /// @param oracles OracleProcess.OracleParam[]
    /// @return (uint256, uint256) The total used value and total borrowing value (in USD)
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

    /// @dev Gets the cross net value and total quantity of the account
    /// @param accountProps Account.Props
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

    /// @dev Gets the cross available value of the account
    /// @param accountProps Account.Props
    /// @return int256 The cross available value (in USD)
    function getCrossAvailableValue(Account.Props storage accountProps) public view returns (int256) {
        OracleProcess.OracleParam[] memory oracles;
        return getCrossAvailableValue(accountProps, oracles);
    }

    /// @dev Gets the cross available value of the account using oracle parameters 
    /// @param accountProps Account.Props
    /// @param oracles OracleProcess.OracleParam[]
    /// @return int256 The cross available value (in USD)
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

    /// @dev Calculates the cross net value for the account
    /// @param cache The position statics cache
    /// @param portfolioNetValue The net value of the portfolio
    /// @param totalUsedValue The total used value
    /// @param orderHoldUsd The order hold value in USD
    /// @return int256 The cross net value (in USD)
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

    /// @dev Gets the net value of a specific token
    /// @param token The address of the token
    /// @param tokenBalance Account.TokenBalance
    /// @param oracles OracleProcess.OracleParam[]
    /// @return uint256 The net value of the token (in USD)
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

    /// @dev Gets the used value of a specific token
    /// @param token The address of the token
    /// @param tokenBalance Account.TokenBalance
    /// @param oracles OracleProcess.OracleParam[]
    /// @return uint256 The used value of the token (in USD)
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

    /// @dev Gets the borrowing value of a specific token
    /// @param token The address of the token
    /// @param tokenBalance Account.TokenBalance
    /// @param oracles OracleProcess.OracleParam[]
    /// @return uint256 The borrowing value of the token  (in USD)
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
