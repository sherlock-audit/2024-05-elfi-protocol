// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/ILiquidation.sol";
import "./PositionQueryProcess.sol";
import "./DecreasePositionProcess.sol";
import "./CancelOrderProcess.sol";

library LiquidationProcess {
    using Math for uint256;
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedSafeMath for int256;
    using Position for Position.Props;
    using DecreasePositionProcess for Position.Props;
    using PositionQueryProcess for Position.Props;
    using Account for Account.Props;
    using AccountProcess for Account.Props;
    using Order for Order.Props;

    event LiquidationAccountIgnored(address account);
    event LiquidationPositionIgnored(bytes32 positionKey);

    bytes32 constant CLEAN_ID_KEY = keccak256("CLEAN_ID_KEY");
    bytes32 constant LIQUIDATION_ID_KEY = keccak256("LIQUIDATION_ID_KEY");

    function liquidationCrossPositions(address account) external {
        Account.Props storage accountProps = Account.load(account);
        Position.Props[] memory crossPositions = PositionQueryProcess.getAllPosition(accountProps, true);
        if (crossPositions.length == 0) {
            revert Errors.OnlyCrossSupported();
        }

        CancelOrderProcess.cancelAllCrossOrders(account, CancelOrderProcess.CANCEL_ORDER_LIQUIDATION);
        for (uint256 i; i < crossPositions.length; i++) {
            Symbol.Props memory symbolProps = Symbol.load(crossPositions[i].symbol);
            MarketProcess.updateMarketFundingFeeRate(crossPositions[i].symbol);
            MarketProcess.updatePoolBorrowingFeeRate(
                symbolProps.stakeToken,
                crossPositions[i].isLong,
                crossPositions[i].marginToken
            );
        }

        if (!accountProps.isCrossLiquidation()) {
            emit LiquidationAccountIgnored(account);
            return;
        }

        (int256 crossNetValue, int256 totalQty) = accountProps.getCrossNetValueAndTotalQty();

        int256 bankruptcyMR = CalUtils.divToIntPrecision(
            crossNetValue,
            totalQty,
            CalUtils.SMALL_RATE_PRECISION.toInt256()
        );

        uint256 requestId = UuidCreator.nextId(LIQUIDATION_ID_KEY);
        for (uint256 i; i < crossPositions.length; i++) {
            Position.Props memory position = crossPositions[i];
            Symbol.Props memory symbolProps = Symbol.load(position.symbol);
            uint256 indexPrice = OracleProcess.getLatestUsdUintPrice(position.indexToken, position.isLong);
            AppConfig.SymbolConfig memory symbolConfig = AppConfig.getSymbolConfig(symbolProps.code);
            uint256 bankruptcyPrice = CalUtils.formatToTickSize(
                position.isLong
                    ? CalUtils.mulSmallRate(
                        indexPrice,
                        (CalUtils.SMALL_RATE_PRECISION.toInt256() - bankruptcyMR).toUint256()
                    )
                    : CalUtils.mulSmallRate(indexPrice, CalUtils.quietAdd(CalUtils.SMALL_RATE_PRECISION, bankruptcyMR)),
                symbolConfig.tickSize,
                position.isLong
            );

            if (bankruptcyPrice == 0) {
                revert Errors.LiquidationErrorWithBankruptcyPriceZero(position.key, bankruptcyMR);
            }

            uint256 liquidationPrice = CalUtils.formatToTickSize(
                position.isLong
                    ? CalUtils.divRate(
                        bankruptcyPrice,
                        CalUtils.RATE_PRECISION - PositionQueryProcess.getPositionMMRate(position)
                    )
                    : CalUtils.divRate(
                        bankruptcyPrice,
                        CalUtils.RATE_PRECISION + PositionQueryProcess.getPositionMMRate(position)
                    ),
                symbolConfig.tickSize,
                position.isLong
            );

            Position.load(position.key).decreasePosition(
                DecreasePositionProcess.DecreasePositionParams(
                    requestId,
                    position.symbol,
                    true,
                    true,
                    position.marginToken,
                    position.qty,
                    liquidationPrice
                )
            );
        }

        _updateClean(accountProps);
    }

    function liquidationIsolatePosition(bytes32 positionKey) external {
        Position.Props storage position = Position.load(positionKey);
        position.checkExists();
        if (position.isCrossMargin) {
            revert Errors.OnlyIsolateSupported();
        }
        MarketProcess.updateMarketFundingFeeRate(position.symbol);
        MarketProcess.updatePoolBorrowingFeeRate(
            Symbol.load(position.symbol).stakeToken,
            position.isLong,
            position.marginToken
        );

        uint256 indexPrice = OracleProcess.getLatestUsdUintPrice(position.indexToken, position.isLong);
        uint256 liquidationPrice = position.getLiquidationPrice();
        if (
            liquidationPrice == 0 ||
            (position.isLong && indexPrice > liquidationPrice) ||
            (!position.isLong && indexPrice < liquidationPrice)
        ) {
            emit LiquidationPositionIgnored(positionKey);
            return;
        }

        CancelOrderProcess.cancelSymbolOrders(
            position.account,
            position.symbol,
            position.marginToken,
            CancelOrderProcess.CANCEL_ORDER_LIQUIDATION
        );

        position.decreasePosition(
            DecreasePositionProcess.DecreasePositionParams(
                UuidCreator.nextId(LIQUIDATION_ID_KEY),
                position.symbol,
                true,
                false,
                position.marginToken,
                position.qty,
                liquidationPrice
            )
        );
    }

    function liquidationLiability(ILiquidation.CleanLiabilityParams calldata params) external {
        Account.Props storage accountProps = Account.load(params.account);
        accountProps.checkExists();
        uint256 cleanId = UuidCreator.nextId(CLEAN_ID_KEY);
        LiabilityClean.LiabilityCleanInfo storage cleanInfo = LiabilityClean.newClean(cleanId);
        cleanInfo.account = params.account;
        cleanInfo.createTime = ChainUtils.currentTimestamp();
        Account.TokenBalance memory tokenBalance = accountProps.getTokenBalance(params.liabilityToken);
        if (tokenBalance.liability == 0 || tokenBalance.liability != params.liability) {
            revert Errors.LiquidationIgnored(params.account);
        }
        cleanInfo.liabilityTokens.push(params.liabilityToken);
        cleanInfo.liabilities.push(tokenBalance.liability);
        accountProps.clearLiability(params.liabilityToken);
        for (uint256 i; i < params.payTokens.length; i++) {
            Account.TokenBalance memory temp = accountProps.getTokenBalance(params.payTokens[i]);
            if (temp.amount < params.payAmounts[i]) {
                revert Errors.BalanceNotEnough(params.account, params.payTokens[i]);
            }
            cleanInfo.collaterals.push(params.payTokens[i]);
            cleanInfo.collateralsAmount.push(params.payAmounts[i]);
            accountProps.subToken(params.payTokens[i], params.payAmounts[i], Account.UpdateSource.LIQUIDATE_LIABILITY);
        }
        LiabilityClean.emitCleanInfo(cleanId, cleanInfo);
    }

    function _updateClean(Account.Props storage accountProps) internal {
        uint256 cleanId = UuidCreator.nextId(CLEAN_ID_KEY);
        LiabilityClean.LiabilityCleanInfo storage cleanInfo = LiabilityClean.newClean(cleanId);
        cleanInfo.account = accountProps.owner;
        cleanInfo.createTime = ChainUtils.currentTimestamp();
        bool hasLiability = false;
        address[] memory tokens = accountProps.getTokens();
        for (uint256 i; i < tokens.length; i++) {
            Account.TokenBalance memory temp = accountProps.getTokenBalance(tokens[i]);
            if (temp.amount > 0) {
                cleanInfo.collaterals.push(tokens[i]);
                cleanInfo.collateralsAmount.push(temp.amount);
            }
            if (temp.liability > 0) {
                cleanInfo.liabilityTokens.push(tokens[i]);
                cleanInfo.liabilities.push(temp.liability);
                accountProps.clearLiability(tokens[i]);
                hasLiability = true;
            }
        }
        for (uint256 i; i < tokens.length; i++) {
            Account.TokenBalance memory temp = accountProps.getTokenBalance(tokens[i]);
            if (temp.amount == 0) {
                continue;
            }
            accountProps.subToken(tokens[i], temp.amount, Account.UpdateSource.LIQUIDATE_CLEAN);
            if (!hasLiability) {
                CommonData.addCleanFunds(tokens[i], temp.amount);
            }
        }
        if (hasLiability) {
            LiabilityClean.emitCleanInfo(cleanId, cleanInfo);
        }
    }
}
