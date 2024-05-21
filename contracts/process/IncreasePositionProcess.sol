// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../storage/Order.sol";
import "./MarketProcess.sol";
import "./LpPoolProcess.sol";
import "./FeeProcess.sol";
import "./AccountProcess.sol";
import "./FeeQueryProcess.sol";

/// @title IncreasePositionProcess
/// @dev Library for increasing position functions 
library IncreasePositionProcess {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedSafeMath for int256;
    using Math for uint256;
    using Position for Position.Props;
    using Order for Order.Props;
    using Account for Account.Props;
    using AccountProcess for Account.Props;

    /// @dev IncreasePositionParams struct used in increasePosition
    ///
    /// @param requestId the unique request id for increasing position
    /// @param marginToken the address of margin token
    /// @param increaseMargin the margin in tokens for increasing position
    /// @param increaseMarginFromBalance the increasePosition's increase margin from the assets actually held by the account 
    /// @param marginTokenPrice the price of margin token
    /// @param indexTokenPrice the price of market index token
    /// @param leverage the new leverage of position
    /// @param isLong position's direction
    /// @param isCrossMargin whether it is a cross-margin position
    struct IncreasePositionParams {
        uint256 requestId;
        address marginToken;
        uint256 increaseMargin;
        uint256 increaseMarginFromBalance;
        uint256 marginTokenPrice;
        uint256 indexTokenPrice;
        uint256 leverage;
        bool isLong;
        bool isCrossMargin;
    }


    /// @dev increase a position
    /// This function performs several operations:
    /// 1. Charges the open fee.
    /// 2. Creates a new position or increases the size of an existing position.
    /// 3. Updates the borrowing fee and funding fee of the original position if it exists.
    /// 4. Updates the market open interest (OI).
    /// 5. Holds an amount in the pool equal to increaseMargin * (leverage - 1).
    ///
    /// @param position Position.Props
    /// @param symbolProps Symbol.Props
    /// @param params IncreasePositionParams
    function increasePosition(
        Position.Props storage position,
        Symbol.Props memory symbolProps,
        IncreasePositionParams calldata params
    ) external {
        uint256 fee = FeeQueryProcess.calcOpenFee(params.increaseMargin, params.leverage, symbolProps.code);
        FeeProcess.chargeTradingFee(fee, symbolProps.code, FeeProcess.FEE_OPEN_POSITION, params.marginToken, position);
        if (params.isCrossMargin) {
            Account.Props storage accountProps = Account.load(position.account);
            accountProps.unUseToken(params.marginToken, fee, Account.UpdateSource.CHARGE_OPEN_FEE);
            accountProps.subTokenWithLiability(params.marginToken, fee, Account.UpdateSource.CHARGE_OPEN_FEE);
        }

        uint256 increaseMargin = params.increaseMargin - fee;
        uint256 increaseMarginFromBalance = params.increaseMarginFromBalance > fee
            ? params.increaseMarginFromBalance - fee
            : 0;

        uint8 tokenDecimals = TokenUtils.decimals(params.marginToken);
        uint256 increaseQty = CalUtils.tokenToUsd(
            CalUtils.mulRate(increaseMargin, params.leverage),
            tokenDecimals,
            params.marginTokenPrice
        );

        AppConfig.SymbolConfig memory symbolConfig = AppConfig.getSymbolConfig(symbolProps.code);
        if (position.qty == 0) {
            position.marginToken = params.marginToken;
            position.entryPrice = params.indexTokenPrice;
            position.initialMargin = increaseMargin;
            position.initialMarginInUsd = CalUtils.tokenToUsd(increaseMargin, tokenDecimals, params.marginTokenPrice);
            position.initialMarginInUsdFromBalance = CalUtils.tokenToUsd(
                increaseMarginFromBalance,
                tokenDecimals,
                params.marginTokenPrice
            );
            position.positionFee.closeFeeInUsd = CalUtils.mulRate(increaseQty, symbolConfig.closeFeeRate);
            position.qty = increaseQty;
            position.leverage = params.leverage;
            position.realizedPnl = -(CalUtils.tokenToUsd(fee, tokenDecimals, params.marginTokenPrice).toInt256());
            position.positionFee.openBorrowingFeePerToken = MarketQueryProcess.getCumulativeBorrowingFeePerToken(
                symbolProps.stakeToken,
                params.isLong,
                params.marginToken
            );
            position.positionFee.openFundingFeePerQty = MarketQueryProcess.getFundingFeePerQty(
                symbolProps.code,
                params.isLong
            );
        } else {
            FeeProcess.updateBorrowingFee(position, symbolProps.stakeToken);
            FeeProcess.updateFundingFee(position);
            position.entryPrice = CalUtils.computeAvgEntryPrice(
                position.qty,
                position.entryPrice,
                increaseQty,
                params.indexTokenPrice,
                symbolConfig.tickSize,
                params.isLong
            );
            position.initialMargin += increaseMargin;
            position.initialMarginInUsd += CalUtils.tokenToUsd(increaseMargin, tokenDecimals, params.marginTokenPrice);
            position.initialMarginInUsdFromBalance += CalUtils.tokenToUsd(
                increaseMarginFromBalance,
                tokenDecimals,
                params.marginTokenPrice
            );
            position.positionFee.closeFeeInUsd += CalUtils.mulRate(increaseQty, symbolConfig.closeFeeRate);
            position.qty += increaseQty;
            position.realizedPnl += -(CalUtils.tokenToUsd(fee, tokenDecimals, params.marginTokenPrice).toInt256());
        }

        position.lastUpdateTime = ChainUtils.currentTimestamp();
        uint256 increaseHoldAmount = CalUtils.mulRate(increaseMargin, (params.leverage - 1 * CalUtils.RATE_PRECISION));
        position.holdPoolAmount += increaseHoldAmount;

        /// update & verify OI
        MarketProcess.updateMarketOI(
            MarketProcess.UpdateOIParams(
                true,
                symbolProps.code,
                params.marginToken,
                increaseQty,
                params.indexTokenPrice,
                params.isLong
            )
        );

        LpPoolProcess.holdPoolAmount(symbolProps.stakeToken, position.marginToken, increaseHoldAmount, params.isLong);

        position.emitOpenPositionUpdateEvent(
            params.requestId,
            Position.PositionUpdateFrom.ORDER_INCREASE,
            params.indexTokenPrice,
            fee
        );
    }
}
