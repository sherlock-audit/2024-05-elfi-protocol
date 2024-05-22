// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../storage/InsuranceFund.sol";
import "./MarketProcess.sol";
import "./LpPoolProcess.sol";
import "./FeeProcess.sol";
import "./AccountProcess.sol";
import "./CancelOrderProcess.sol";
import "./FeeQueryProcess.sol";
import "./PositionMarginProcess.sol";

/// @title DecreasePositionProcess
/// @dev Library for decreasing position functions 
library DecreasePositionProcess {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedSafeMath for int256;
    using Math for uint256;
    using Position for Position.Props;
    using Order for Order.Props;
    using Account for Account.Props;
    using AccountProcess for Account.Props;
    using Market for Market.Props;

    /// @dev DecreasePositionParams struct used in decreasePosition
    ///
    /// @param requestId the unique request id for decreasing position
    /// @param symbol position's market
    /// @param isLiquidation liquidation a position
    /// @param isCrossMargin whether it is a cross-margin position
    /// @param marginToken the address of margin token
    /// @param decreaseQty closed size of position
    /// @param executePrice the index token price of decreasing position
    struct DecreasePositionParams {
        uint256 requestId;
        bytes32 symbol;
        bool isLiquidation;
        bool isCrossMargin;
        address marginToken;
        uint256 decreaseQty;
        uint256 executePrice;
    }

    /// @dev DecreasePositionCache struct used to record intermediate state values to avoid stack too deep errors
    ///
    /// @param stakeToken the address of the pool.
    /// @param position Position.Props.
    /// @param marginTokenPrice The price of the margin token.
    /// @param executePrice The price at which the position is decreased.
    /// @param recordPnlToken The recorded profit and loss in tokens.
    /// @param settledMargin The settled margin amount.
    /// @param decreaseMargin The amount by which the margin is decreased.
    /// @param decreaseIntQty The integer quantity by which the position is decreased.
    /// @param positionIntQty The integer quantity of the position.
    /// @param decreaseMarginInUsd The amount by which the margin is decreased, in USD.
    /// @param decreaseMarginInUsdFromBalance The amount by which the margin is decreased from the balance, in USD.
    /// @param settledBorrowingFee The settled borrowing fee.
    /// @param settledBorrowingFeeInUsd The settled borrowing fee, in USD.
    /// @param settledFundingFee The settled funding fee.
    /// @param settledFundingFeeInUsd The settled funding fee, in USD.
    /// @param settledFee The total settled fee.
    /// @param unHoldPoolAmount The amount unheld in the pool.
    /// @param closeFee The closing fee.
    /// @param closeFeeInUsd The closing fee, in USD.
    /// @param realizedPnl The realized profit and loss.
    /// @param poolPnlToken The profit and loss in the pool, in tokens.
    /// @param isLiquidation Indicates if the position is being liquidated
    struct DecreasePositionCache {
        address stakeToken;
        Position.Props position;
        uint256 marginTokenPrice;
        int256 executePrice;
        int256 recordPnlToken;
        int256 settledMargin;
        uint256 decreaseMargin;
        int256 decreaseIntQty;
        int256 positionIntQty;
        uint256 decreaseMarginInUsd;
        uint256 decreaseMarginInUsdFromBalance;
        uint256 settledBorrowingFee;
        uint256 settledBorrowingFeeInUsd;
        int256 settledFundingFee;
        int256 settledFundingFeeInUsd;
        int256 settledFee;
        uint256 unHoldPoolAmount;
        uint256 closeFee;
        uint256 closeFeeInUsd;
        int256 realizedPnl;
        int256 poolPnlToken;
        bool isLiquidation;
    }

    /// @notice Decreases a position by closing it or partially closing it, including liquidation.
    /// @dev The decreasePosition function performs the following steps:
    /// 1. Calculates the unrealized profit and loss (PnL) of the position in USD.
    /// 2. Updates the borrowing fee and funding fee of the original position.
    /// 3. Settles the position and the pool.
    /// 4. Updates market-related information.
    ///
    /// During settlement, all fees are settled first, followed by the initial margin and PnL.
    /// Settlement fees include borrow fee, close fee, and funding fee, and their actual token assets will be stored in the Market Vault (stakeToken).
    /// The settled margin is the amount of funds settled for the user:
    /// - For isolated positions, the settled margin will be transferred to the user's own wallet.
    /// - For cross margin, the funds will remain in the PortfolioVault.
    /// The transfer of vault funds is executed in _settleCrossAccount and _settleIsolateAccount, while other logic uses virtual accounting.
    ///
    /// After cross margin settlement, the user may incur a debt, which will be recorded in the account liability. When the user's debt exceeds a certain limit, the keeper will trigger the logic for the user to actively repay the liability. 
    /// The user will also prioritize repaying the debt after making a deposit or closing a position with a profit.
    ///
    /// @param position Position.Props
    /// @param params DecreasePositionParams
    function decreasePosition(Position.Props storage position, DecreasePositionParams calldata params) external {
        int256 totalPnlInUsd = PositionQueryProcess.getPositionUnPnl(position, params.executePrice.toInt256(), false);
        Symbol.Props memory symbolProps = Symbol.load(params.symbol);
        AppConfig.SymbolConfig memory symbolConfig = AppConfig.getSymbolConfig(params.symbol);
        FeeProcess.updateBorrowingFee(position, symbolProps.stakeToken);
        FeeProcess.updateFundingFee(position);
        DecreasePositionCache memory cache = _updateDecreasePosition(
            position,
            params.decreaseQty,
            totalPnlInUsd,
            params.executePrice.toInt256(),
            symbolConfig.closeFeeRate,
            params.isLiquidation,
            params.isCrossMargin
        );
        if (cache.settledMargin < 0 && !cache.isLiquidation && !position.isCrossMargin) {
            revert Errors.PositionShouldBeLiquidation();
        }
        cache.stakeToken = symbolProps.stakeToken;
        cache.isLiquidation = params.isLiquidation;

        Account.Props storage accountProps = Account.load(position.account);
        if (params.decreaseQty == position.qty) {
            accountProps.delPosition(
                Position.getPositionKey(position.account, position.symbol, position.marginToken, position.isCrossMargin)
            );
            position.reset();
        } else {
            position.qty -= params.decreaseQty;
            position.initialMargin -= cache.decreaseMargin;
            position.initialMarginInUsd -= cache.decreaseMarginInUsd;
            position.initialMarginInUsdFromBalance -= cache.decreaseMarginInUsdFromBalance;
            position.holdPoolAmount -= cache.unHoldPoolAmount;
            position.realizedPnl += cache.realizedPnl;
            position.positionFee.realizedBorrowingFee -= cache.settledBorrowingFee;
            position.positionFee.realizedBorrowingFeeInUsd -= cache.settledBorrowingFeeInUsd;
            position.positionFee.realizedFundingFee -= cache.settledFundingFee;
            position.positionFee.realizedFundingFeeInUsd -= cache.settledFundingFeeInUsd;
            position.positionFee.closeFeeInUsd -= cache.closeFeeInUsd;
            position.lastUpdateTime = ChainUtils.currentTimestamp();
        }

        FeeProcess.chargeTradingFee(
            cache.closeFee,
            symbolProps.code,
            cache.isLiquidation ? FeeProcess.FEE_LIQUIDATION : FeeProcess.FEE_CLOSE_POSITION,
            cache.position.marginToken,
            cache.position
        );

        FeeProcess.chargeBorrowingFee(
            position.isCrossMargin,
            cache.settledBorrowingFee,
            symbolProps.stakeToken,
            cache.position.marginToken,
            position.account,
            cache.isLiquidation ? FeeProcess.FEE_LIQUIDATION : FeeProcess.FEE_BORROWING
        );

        if (cache.position.isCrossMargin) {
            uint256 addLiability = _settleCrossAccount(params.requestId, accountProps, position, cache);
            accountProps.repayLiability(cache.position.marginToken);
            LpPoolProcess.updatePnlAndUnHoldPoolAmount(
                symbolProps.stakeToken,
                cache.position.marginToken,
                cache.unHoldPoolAmount,
                cache.poolPnlToken,
                addLiability
            );
        } else {
            _settleIsolateAccount(accountProps, cache);
            LpPoolProcess.updatePnlAndUnHoldPoolAmount(
                symbolProps.stakeToken,
                cache.position.marginToken,
                cache.unHoldPoolAmount,
                cache.poolPnlToken,
                0
            );
        }

        /// update total borrowing
        MarketProcess.updateTotalBorrowingFee(
            symbolProps.stakeToken,
            cache.position.isLong,
            cache.position.marginToken,
            cache.settledBorrowingFee.toInt256(),
            -cache.settledBorrowingFee.toInt256()
        );

        /// update funding fee
        MarketProcess.updateMarketFundingFee(
            symbolProps.code,
            -cache.settledFundingFee,
            cache.position.isLong,
            !position.isCrossMargin,
            cache.position.marginToken
        );

        /// update & verify OI
        MarketProcess.updateMarketOI(
            MarketProcess.UpdateOIParams(
                false,
                symbolProps.code,
                cache.position.marginToken,
                params.decreaseQty,
                0,
                cache.position.isLong
            )
        );

        /// cancel stop orders
        CancelOrderProcess.cancelStopOrders(
            cache.position.account,
            symbolProps.code,
            cache.position.marginToken,
            cache.position.isCrossMargin,
            CancelOrderProcess.CANCEL_ORDER_POSITION_CLOSE,
            params.requestId
        );

        /// update insuranceFund
        if (cache.isLiquidation) {
            _addFunds(cache);
        }

        position.emitPositionUpdateEvent(
            params.requestId,
            cache.isLiquidation ? Position.PositionUpdateFrom.LIQUIDATION : Position.PositionUpdateFrom.ORDER_DECREASE,
            Position.SettleData(
                params.executePrice,
                0,
                cache.marginTokenPrice,
                cache.settledMargin,
                cache.settledBorrowingFee,
                cache.settledBorrowingFeeInUsd,
                cache.settledFundingFee,
                cache.settledFundingFeeInUsd,
                cache.unHoldPoolAmount,
                cache.closeFee,
                cache.closeFeeInUsd,
                cache.realizedPnl,
                cache.poolPnlToken
            )
        );
    }

    /// @dev Calculates all settlement values for the positionn.
    /// @param position Position.Props.
    /// @param decreaseQty The quantity to decrease.
    /// @param pnlInUsd The profit and loss in USD.
    /// @param executePrice The execution price of market index token.
    /// @param closeFeeRate The close fee rate.
    /// @param isLiquidation Whether the position is being liquidated.
    /// @param isCrossMargin Whether the position is cross margin.
    /// @return cache DecreasePositionCache.
    function _updateDecreasePosition(
        Position.Props storage position,
        uint256 decreaseQty,
        int256 pnlInUsd,
        int256 executePrice,
        uint256 closeFeeRate,
        bool isLiquidation,
        bool isCrossMargin
    ) internal view returns (DecreasePositionCache memory cache) {
        cache.position = position;
        cache.executePrice = executePrice;
        int256 tokenPrice = OracleProcess.getLatestUsdPrice(position.marginToken, false);
        cache.marginTokenPrice = tokenPrice.toUint256();
        uint8 tokenDecimals = TokenUtils.decimals(position.marginToken);
        if (position.qty == decreaseQty) {
            cache.decreaseMargin = cache.position.initialMargin;
            cache.decreaseMarginInUsd = cache.position.initialMarginInUsd;
            cache.unHoldPoolAmount = cache.position.holdPoolAmount;
            (cache.settledBorrowingFee, cache.settledBorrowingFeeInUsd) = FeeQueryProcess.calcBorrowingFee(
                decreaseQty,
                position
            );
            cache.settledFundingFee = cache.position.positionFee.realizedFundingFee;
            cache.settledFundingFeeInUsd = cache.position.positionFee.realizedFundingFeeInUsd;

            cache.closeFeeInUsd = cache.position.positionFee.closeFeeInUsd;
            cache.closeFee = FeeQueryProcess.calcCloseFee(tokenDecimals, cache.closeFeeInUsd, tokenPrice.toUint256());
            cache.settledFee =
                cache.settledBorrowingFee.toInt256() +
                cache.settledFundingFee +
                cache.closeFee.toInt256();

            if (isLiquidation) {
                cache.settledMargin = isCrossMargin
                    ? CalUtils.usdToTokenInt(
                        cache.position.initialMarginInUsd.toInt256() -
                            _getPosFee(cache) +
                            pnlInUsd -
                            PositionQueryProcess.getPositionMM(cache.position).toInt256(),
                        TokenUtils.decimals(cache.position.marginToken),
                        tokenPrice
                    )
                    : int256(0);
                cache.recordPnlToken = cache.settledMargin - cache.decreaseMargin.toInt256();
                cache.poolPnlToken =
                    cache.decreaseMargin.toInt256() -
                    CalUtils.usdToTokenInt(
                        cache.position.initialMarginInUsd.toInt256() + pnlInUsd,
                        TokenUtils.decimals(cache.position.marginToken),
                        tokenPrice
                    );
            } else {
                cache.settledMargin = CalUtils.usdToTokenInt(
                    cache.position.initialMarginInUsd.toInt256() - _getPosFee(cache) + pnlInUsd,
                    TokenUtils.decimals(cache.position.marginToken),
                    tokenPrice
                );
                cache.recordPnlToken = cache.settledMargin - cache.decreaseMargin.toInt256();
                cache.poolPnlToken =
                    cache.decreaseMargin.toInt256() -
                    CalUtils.usdToTokenInt(
                        cache.position.initialMarginInUsd.toInt256() + pnlInUsd,
                        TokenUtils.decimals(cache.position.marginToken),
                        tokenPrice
                    );
            }
            cache.realizedPnl = CalUtils.tokenToUsdInt(
                cache.recordPnlToken,
                TokenUtils.decimals(cache.position.marginToken),
                tokenPrice
            );
        } else {
            cache.decreaseMargin = cache.position.initialMargin.mul(decreaseQty).div(cache.position.qty);
            cache.unHoldPoolAmount = cache.position.holdPoolAmount.mul(decreaseQty).div(cache.position.qty);
            cache.closeFeeInUsd = CalUtils.mulRate(decreaseQty, closeFeeRate);
            (cache.settledBorrowingFee, cache.settledBorrowingFeeInUsd) = FeeQueryProcess.calcBorrowingFee(
                decreaseQty,
                position
            );
            cache.decreaseIntQty = decreaseQty.toInt256();
            cache.positionIntQty = cache.position.qty.toInt256();
            cache.settledFundingFee = cache.position.positionFee.realizedFundingFee.mul(cache.decreaseIntQty).div(
                cache.positionIntQty
            );
            cache.settledFundingFeeInUsd = cache
                .position
                .positionFee
                .realizedFundingFeeInUsd
                .mul(cache.decreaseIntQty)
                .div(cache.positionIntQty);

            if (cache.closeFeeInUsd > cache.position.positionFee.closeFeeInUsd) {
                cache.closeFeeInUsd = cache.position.positionFee.closeFeeInUsd;
            }
            cache.closeFee = FeeQueryProcess.calcCloseFee(tokenDecimals, cache.closeFeeInUsd, tokenPrice.toUint256());
            cache.settledFee =
                cache.settledBorrowingFee.toInt256() +
                cache.settledFundingFee +
                cache.closeFee.toInt256();
            cache.settledMargin = CalUtils.usdToTokenInt(
                (cache.position.initialMarginInUsd.toInt256() - _getPosFee(cache) + pnlInUsd)
                    .mul(cache.decreaseIntQty)
                    .div(cache.positionIntQty),
                TokenUtils.decimals(cache.position.marginToken),
                tokenPrice
            );
            cache.recordPnlToken = cache.settledMargin - cache.decreaseMargin.toInt256();
            cache.poolPnlToken =
                cache.decreaseMargin.toInt256() -
                CalUtils.usdToTokenInt(
                    (cache.position.initialMarginInUsd.toInt256() + pnlInUsd).mul(cache.decreaseIntQty).div(
                        cache.positionIntQty
                    ),
                    TokenUtils.decimals(cache.position.marginToken),
                    tokenPrice
                );
            cache.decreaseMarginInUsd = cache.position.initialMarginInUsd.mul(decreaseQty).div(position.qty);
            cache.realizedPnl = CalUtils.tokenToUsdInt(
                cache.recordPnlToken,
                TokenUtils.decimals(cache.position.marginToken),
                tokenPrice
            );
        }

        cache.decreaseMarginInUsdFromBalance = (cache.decreaseMarginInUsd + position.initialMarginInUsdFromBalance >
            position.initialMarginInUsd)
            ? cache.decreaseMarginInUsd + position.initialMarginInUsdFromBalance - position.initialMarginInUsd
            : 0;

        return cache;
    }

    /// @dev Settles the cross margin position.
    /// @param requestId The request ID.
    /// @param accountProps Account.Props.
    /// @param position Position.Props.
    /// @param cache DecreasePositionCache.
    /// @return addLiability The additional liability.
    function _settleCrossAccount(
        uint256 requestId,
        Account.Props storage accountProps,
        Position.Props storage position,
        DecreasePositionCache memory cache
    ) internal returns (uint256 addLiability) {
        if (cache.settledFee > 0) {
            accountProps.subTokenWithLiability(
                cache.position.marginToken,
                cache.settledFee.toUint256(),
                Account.UpdateSource.SETTLE_FEE
            );
        } else {
            accountProps.addToken(
                cache.position.marginToken,
                (-cache.settledFee).toUint256(),
                Account.UpdateSource.SETTLE_FEE
            );
        }
        accountProps.unUseToken(
            cache.position.marginToken,
            cache.decreaseMargin,
            Account.UpdateSource.DECREASE_POSITION
        );
        address portfolioVault = IVault(address(this)).getPortfolioVaultAddress();
        if (cache.recordPnlToken >= 0) {
            accountProps.addToken(
                cache.position.marginToken,
                (cache.recordPnlToken + cache.settledFee).toUint256(),
                Account.UpdateSource.SETTLE_PNL
            );
            VaultProcess.transferOut(
                cache.position.isLong ? cache.stakeToken : CommonData.getStakeUsdToken(),
                cache.position.marginToken,
                portfolioVault,
                cache.recordPnlToken.toUint256(),
                true
            );
            if (!cache.position.isLong) {
                VaultProcess.transferOut(
                    CommonData.getStakeUsdToken(),
                    cache.position.marginToken,
                    cache.stakeToken,
                    cache.closeFee,
                    true
                );
            }
        } else if (cache.recordPnlToken < 0) {
            addLiability = accountProps.subTokenWithLiability(
                cache.position.marginToken,
                (-cache.recordPnlToken).toUint256()
            );
            VaultProcess.transferOut(
                portfolioVault,
                cache.position.marginToken,
                cache.stakeToken,
                (-cache.recordPnlToken).toUint256() - addLiability,
                true
            );
        }
        if (!cache.isLiquidation) {
            int256 changeToken = (
                cache.decreaseMarginInUsdFromBalance.mul(cache.position.initialMargin).div(
                    cache.position.initialMarginInUsd
                )
            ).toInt256() +
                cache.settledMargin -
                cache.decreaseMargin.toInt256();
            PositionMarginProcess.updateAllPositionFromBalanceMargin(
                requestId,
                accountProps.owner,
                cache.position.marginToken,
                changeToken,
                position.key
            );
        }
    }

    /// @dev Settles an isolated margin position.
    /// @param accountProps Account.Props.
    /// @param cache DecreasePositionCache.
    function _settleIsolateAccount(Account.Props storage accountProps, DecreasePositionCache memory cache) internal {
        if (cache.isLiquidation) {
            return;
        }
        if (cache.recordPnlToken < 0 || (cache.recordPnlToken >= 0 && cache.position.isLong)) {
            VaultProcess.transferOut(
                cache.stakeToken,
                cache.position.marginToken,
                accountProps.owner,
                cache.settledMargin.toUint256(),
                true
            );
        } else {
            VaultProcess.transferOut(
                CommonData.getStakeUsdToken(),
                cache.position.marginToken,
                cache.stakeToken,
                cache.recordPnlToken.toUint256() + cache.closeFee,
                true
            );
            VaultProcess.transferOut(
                cache.stakeToken,
                cache.position.marginToken,
                accountProps.owner,
                cache.settledMargin.toUint256(),
                true
            );
        }
    }

    /// @dev Adds funds to the insurance fund.
    /// @param cache DecreasePositionCache.
    function _addFunds(DecreasePositionCache memory cache) internal {
        if (cache.position.isCrossMargin) {
            InsuranceFund.addFunds(
                cache.stakeToken,
                cache.position.marginToken,
                CalUtils.usdToToken(
                    PositionQueryProcess.getPositionMM(cache.position),
                    TokenUtils.decimals(cache.position.marginToken),
                    cache.marginTokenPrice
                )
            );
            return;
        }
        uint256 addFunds;
        if (cache.settledFee >= 0) {
            addFunds = cache.decreaseMargin > (cache.settledFee + cache.poolPnlToken).toUint256()
                ? cache.decreaseMargin - (cache.settledFee + cache.poolPnlToken).toUint256()
                : 0;
        } else {
            addFunds = cache.decreaseMargin + (-cache.settledFee).toUint256() - cache.poolPnlToken.toUint256();
        }
        InsuranceFund.addFunds(cache.stakeToken, cache.position.marginToken, addFunds);
    }

    /// @dev Calculates the position fee.
    /// @param cache DecreasePositionCache.
    /// @return The calculated position fee.
    function _getPosFee(DecreasePositionCache memory cache) internal pure returns (int256) {
        return
            cache.closeFeeInUsd.toInt256() + cache.settledBorrowingFeeInUsd.toInt256() + cache.settledFundingFeeInUsd;
    }
}
