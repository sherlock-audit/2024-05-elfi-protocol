// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../storage/Order.sol";
import "./MarketProcess.sol";
import "./LpPoolProcess.sol";
import "./FeeProcess.sol";
import "./AccountProcess.sol";
import "./FeeQueryProcess.sol";

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

        // update & verify OI
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
