// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/IAccount.sol";
import "../interfaces/IOrder.sol";
import "./DecreasePositionProcess.sol";
import "./IncreasePositionProcess.sol";
import "./AssetsProcess.sol";
import "./GasProcess.sol";
import "./LpPoolProcess.sol";
import "./FeeProcess.sol";

library OrderProcess {
    using Order for Order.Props;
    using Position for Position.Props;
    using IncreasePositionProcess for Position.Props;
    using DecreasePositionProcess for Position.Props;
    using Account for Account.Props;
    using AccountProcess for Account.Props;
    using Symbol for Symbol.Props;
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;

    bytes32 constant ORDER_ID_KEY = keccak256("ORDER_ID_KEY");

    event PlaceOrderEvent(uint256 indexed orderId, Order.OrderInfo data);
    event OrderFilledEvent(uint256 indexed orderId, Order.OrderInfo data, uint256 fillTime, uint256 fillPrice);
    event CancelOrderEvent(uint256 indexed orderId, Order.OrderInfo data, bytes32 reasonCode);

    struct ExecuteOrderParams {
        uint256 orderId;
        address keeper;
    }

    struct ExecuteIncreaseOrderCache {
        uint256 executionPrice;
        uint256 orderMargin;
        uint256 orderMarginFromBalance;
        address marginToken;
        uint256 marginTokenPrice;
        bool isLong;
    }

    function createOrderRequest(
        Account.Props storage accountProps,
        IOrder.PlaceOrderParams calldata params,
        bool validateExecutionFee
    ) external {
        _validatePlaceOrder(params);
        if (
            params.posSide == Order.PositionSide.INCREASE &&
            params.orderSide == Order.Side.SHORT &&
            (PositionQueryProcess.hasOtherShortPosition(
                accountProps.owner,
                params.symbol,
                params.marginToken,
                params.isCrossMargin
            ) ||
                Order.hasOtherShortOrders(
                    accountProps.getAllOrders(),
                    params.symbol,
                    params.marginToken,
                    params.isCrossMargin
                ))
        ) {
            revert Errors.OnlyOneShortPositionSupport(params.symbol);
        }

        (uint256 orderMargin, bool isExecutionFeeFromTradeVault) = validateExecutionFee
            ? _validateGasFeeLimitAndInitialMargin(accountProps, params)
            : (params.orderMargin, !params.isCrossMargin);

        uint256 orderId = UuidCreator.nextId(ORDER_ID_KEY);
        Order.OrderInfo storage order = Order.create(orderId);
        order.account = accountProps.owner;
        order.symbol = params.symbol;
        order.orderSide = params.orderSide;
        order.posSide = params.posSide;
        order.orderType = params.orderType;
        order.marginToken = params.marginToken;
        order.orderMargin = orderMargin;
        order.qty = params.qty;
        order.triggerPrice = params.triggerPrice;
        order.acceptablePrice = params.acceptablePrice;
        order.stopType = params.stopType;
        order.isCrossMargin = params.isCrossMargin;
        order.isExecutionFeeFromTradeVault = isExecutionFeeFromTradeVault;
        order.executionFee = params.executionFee;
        order.leverage = params.leverage;
        order.placeTime = params.placeTime;
        order.lastBlock = ChainUtils.currentBlock();
        if (Order.PositionSide.INCREASE == params.posSide && order.isCrossMargin) {
            accountProps.addOrderHoldInUsd(orderMargin);
        }
        accountProps.addOrder(orderId);
        emit PlaceOrderEvent(orderId, order);
    }

    function executeOrder(uint256 orderId, Order.OrderInfo memory order) external {
        Symbol.Props memory symbolProps = Symbol.load(order.symbol);

        _validExecuteOrder(order, symbolProps);
        if (Order.PositionSide.INCREASE == order.posSide) {
            _executeIncreaseOrder(orderId, order, symbolProps);
        } else if (Order.PositionSide.DECREASE == order.posSide) {
            _executeDecreaseOrder(orderId, order, symbolProps);
        }
        Order.remove(orderId);
    }

    function _executeIncreaseOrder(
        uint256 orderId,
        Order.OrderInfo memory order,
        Symbol.Props memory symbolProps
    ) internal {
        if (
            order.posSide == Order.PositionSide.INCREASE &&
            order.orderSide == Order.Side.SHORT &&
            PositionQueryProcess.hasOtherShortPosition(
                order.account,
                order.symbol,
                order.marginToken,
                order.isCrossMargin
            )
        ) {
            revert Errors.OnlyOneShortPositionSupport(order.symbol);
        }
        Account.Props storage accountProps = Account.load(order.account);

        ExecuteIncreaseOrderCache memory cache;
        cache.isLong = Order.Side.LONG == order.orderSide;

        MarketProcess.updateMarketFundingFeeRate(symbolProps.code);
        MarketProcess.updatePoolBorrowingFeeRate(symbolProps.stakeToken, cache.isLong, order.marginToken);

        cache.executionPrice = _getExecutionPrice(order, symbolProps.indexToken);
        if (symbolProps.indexToken == order.marginToken) {
            cache.marginTokenPrice = cache.executionPrice;
        } else {
            cache.marginTokenPrice = OracleProcess.getLatestUsdUintPrice(order.marginToken, !cache.isLong);
        }

        (cache.orderMargin, cache.orderMarginFromBalance) = _executeIncreaseOrderMargin(
            order,
            accountProps,
            cache.marginTokenPrice
        );

        if (!order.isCrossMargin) {
            VaultProcess.transferOut(
                IVault(address(this)).getTradeVaultAddress(),
                order.marginToken,
                symbolProps.stakeToken,
                cache.orderMargin
            );
        }

        Position.Props storage positionProps = Position.load(
            order.account,
            symbolProps.code,
            order.marginToken,
            order.isCrossMargin
        );
        if (positionProps.qty == 0) {
            if (
                accountProps.hasOtherOrder(orderId) &&
                _getOrderLeverage(
                    accountProps,
                    symbolProps.code,
                    order.orderSide,
                    order.isCrossMargin,
                    order.leverage
                ) !=
                order.leverage
            ) {
                revert Errors.UpdateLeverageError(
                    order.account,
                    symbolProps.code,
                    Order.Side.LONG == order.orderSide,
                    _getOrderLeverage(
                        accountProps,
                        symbolProps.code,
                        order.orderSide,
                        order.isCrossMargin,
                        order.leverage
                    ),
                    order.leverage
                );
            }
            bytes32 key = Position.getPositionKey(
                order.account,
                symbolProps.code,
                order.marginToken,
                order.isCrossMargin
            );
            positionProps.key = key;
            positionProps.account = order.account;
            positionProps.indexToken = symbolProps.indexToken;
            positionProps.symbol = symbolProps.code;
            positionProps.marginToken = order.marginToken;
            positionProps.leverage = order.leverage;
            positionProps.isLong = cache.isLong;
            positionProps.isCrossMargin = order.isCrossMargin;
            accountProps.addPosition(key);
        } else if (positionProps.leverage != order.leverage) {
            revert Errors.UpdateLeverageError(
                order.account,
                symbolProps.code,
                Order.Side.LONG == order.orderSide,
                positionProps.leverage,
                order.leverage
            );
        }
        positionProps.increasePosition(
            symbolProps,
            IncreasePositionProcess.IncreasePositionParams(
                orderId,
                order.marginToken,
                cache.orderMargin,
                cache.orderMarginFromBalance,
                cache.marginTokenPrice,
                cache.executionPrice,
                order.leverage,
                cache.isLong,
                order.isCrossMargin
            )
        );
        accountProps.delOrder(orderId);

        emit OrderFilledEvent(orderId, order, block.timestamp, cache.executionPrice);
    }

    function _getExecutionPrice(Order.OrderInfo memory order, address indexToken) internal view returns (uint256) {
        bool isMinPrice;
        if (Order.PositionSide.INCREASE == order.posSide) {
            isMinPrice = Order.Side.SHORT == order.orderSide;
        } else {
            isMinPrice = Order.Side.LONG == order.orderSide;
        }
        if (Order.Type.MARKET == order.orderType) {
            uint256 indexPrice = OracleProcess.getLatestUsdUintPrice(indexToken, isMinPrice);
            if (
                (isMinPrice && order.acceptablePrice > 0 && indexPrice < order.acceptablePrice) ||
                (!isMinPrice && order.acceptablePrice > 0 && indexPrice > order.acceptablePrice)
            ) {
                revert Errors.ExecutionPriceInvalid();
            }
            return indexPrice;
        }
        uint256 currentPrice = OracleProcess.getLatestUsdUintPrice(indexToken, isMinPrice);
        bool isLong = Order.Side.LONG == order.orderSide;
        if (
            Order.Type.LIMIT == order.orderType ||
            (Order.Type.STOP == order.orderType && Order.StopType.TAKE_PROFIT == order.stopType)
        ) {
            if ((isLong && order.triggerPrice >= currentPrice) || (!isLong && order.triggerPrice <= currentPrice)) {
                return currentPrice;
            }
            revert Errors.ExecutionPriceInvalid();
        }
        if (Order.Type.STOP == order.orderType && Order.StopType.STOP_LOSS == order.stopType) {
            if ((isLong && order.triggerPrice <= currentPrice) || (!isLong && order.triggerPrice >= currentPrice)) {
                return currentPrice;
            }
            revert Errors.ExecutionPriceInvalid();
        }
        revert Errors.ExecutionPriceInvalid();
    }

    function _executeIncreaseOrderMargin(
        Order.OrderInfo memory order,
        Account.Props storage accountProps,
        uint256 marginTokenPrice
    ) internal returns (uint256 orderMargin, uint256 orderMarginFromBalance) {
        address marginToken = order.marginToken;
        address account = accountProps.owner;
        if (order.isCrossMargin) {
            if (accountProps.getCrossAvailableValue() < 0) {
                int256 fixOrderMarginInUsd = order.orderMargin.toInt256() + accountProps.getCrossAvailableValue();
                if (fixOrderMarginInUsd <= 0) {
                    revert Errors.BalanceNotEnough(account, marginToken);
                }
                accountProps.subOrderHoldInUsd(order.orderMargin);
                order.orderMargin = fixOrderMarginInUsd.toUint256();
            } else {
                accountProps.subOrderHoldInUsd(order.orderMargin);
            }

            orderMargin = CalUtils.usdToToken(order.orderMargin, TokenUtils.decimals(marginToken), marginTokenPrice);
            orderMarginFromBalance = accountProps.useToken(
                marginToken,
                orderMargin,
                false,
                Account.UpdateSource.INCREASE_POSITION
            );
        } else {
            uint256 orderMarginInUsd = CalUtils.tokenToUsd(
                order.orderMargin,
                TokenUtils.decimals(marginToken),
                marginTokenPrice
            );
            if (orderMarginInUsd < AppTradeConfig.getTradeConfig().minOrderMarginUSD) {
                revert Errors.OrderMarginTooSmall();
            }
            orderMargin = order.orderMargin;
            orderMarginFromBalance = order.orderMargin;
        }
    }

    function _isUserPlaceOrder(Order.Type orderType) internal pure returns (bool) {
        return Order.Type.LIMIT == orderType || Order.Type.MARKET == orderType || Order.Type.STOP == orderType;
    }

    function _validExecuteOrder(Order.OrderInfo memory order, Symbol.Props memory symbolProps) internal view {
        AppConfig.SymbolConfig memory symbolConfig = AppConfig.getSymbolConfig(symbolProps.code);
        bool isIncrease = Order.PositionSide.INCREASE == order.posSide;
        bool isLong = Order.Side.LONG == order.orderSide;
        if (_isUserPlaceOrder(order.orderType) && isIncrease && Symbol.Status.OPEN != symbolProps.status) {
            revert Errors.SymbolStatusInvalid(order.symbol);
        }

        // token verify
        if (isIncrease) {
            if (isLong && order.marginToken != symbolProps.baseToken) {
                revert Errors.TokenInvalid(order.symbol, order.marginToken);
            }
            if (!isLong && !UsdPool.isSupportStableToken(order.marginToken)) {
                revert Errors.TokenInvalid(order.symbol, order.marginToken);
            }
        }

        if (order.leverage > symbolConfig.maxLeverage || order.leverage < 1 * CalUtils.RATE_PRECISION) {
            revert Errors.LeverageInvalid(order.symbol, order.leverage);
        }
    }

    function _getOrderLeverage(
        Account.Props storage accountProps,
        bytes32 symbol,
        Order.Side orderSide,
        bool isCrossMargin,
        uint256 defaultLeverage
    ) internal view returns (uint256) {
        uint256[] memory orders = accountProps.getAllOrders();
        Order.Props storage orderProps = Order.load();
        for (uint256 i; i < orders.length; i++) {
            Order.OrderInfo memory orderInfo = orderProps.get(orders[i]);
            if (
                orderInfo.symbol == symbol &&
                orderInfo.orderSide == orderSide &&
                orderInfo.posSide != Order.PositionSide.DECREASE &&
                orderInfo.isCrossMargin == isCrossMargin
            ) {
                return orderInfo.leverage;
            }
        }
        return defaultLeverage;
    }

    function _validatePlaceOrder(IOrder.PlaceOrderParams calldata params) internal view {
        if (
            Order.Type.MARKET != params.orderType &&
            Order.Type.LIMIT != params.orderType &&
            Order.Type.STOP != params.orderType
        ) {
            revert Errors.PlaceOrderWithParamsError();
        }

        if (Order.PositionSide.DECREASE == params.posSide && params.qty == 0) {
            revert Errors.PlaceOrderWithParamsError();
        }

        if (Order.Side.NONE == params.orderSide) {
            revert Errors.PlaceOrderWithParamsError();
        }

        if (Order.Type.LIMIT == params.orderType && params.triggerPrice == 0) {
            revert Errors.PlaceOrderWithParamsError();
        }

        if (Order.Type.LIMIT == params.orderType && Order.PositionSide.DECREASE == params.posSide) {
            revert Errors.PlaceOrderWithParamsError();
        }

        if (
            Order.Type.STOP == params.orderType && (Order.StopType.NONE == params.stopType || params.triggerPrice == 0)
        ) {
            revert Errors.PlaceOrderWithParamsError();
        }

        if (Order.PositionSide.INCREASE == params.posSide) {
            if (params.orderMargin == 0) {
                revert Errors.PlaceOrderWithParamsError();
            }
            Symbol.Props storage symbolProps = Symbol.load(params.symbol);
            if (!symbolProps.isSupportIncreaseOrder()) {
                revert Errors.SymbolStatusInvalid(params.symbol);
            }
            if (Order.Side.LONG == params.orderSide && params.marginToken != symbolProps.baseToken) {
                revert Errors.PlaceOrderWithParamsError();
            }
            if (Order.Side.SHORT == params.orderSide && !UsdPool.isSupportStableToken(params.marginToken)) {
                revert Errors.PlaceOrderWithParamsError();
            }
            if (params.isCrossMargin && params.orderMargin < AppTradeConfig.getTradeConfig().minOrderMarginUSD) {
                revert Errors.PlaceOrderWithParamsError();
            }
        }
    }

    function _executeDecreaseOrder(
        uint256 orderId,
        Order.OrderInfo memory order,
        Symbol.Props memory symbolProps
    ) internal {
        address account = order.account;
        bool isLong = Order.Side.LONG == order.orderSide;

        Position.Props storage position = Position.load(account, order.symbol, order.marginToken, order.isCrossMargin);
        position.checkExists();

        if (position.isLong == isLong) {
            revert Errors.DecreaseOrderSideInvalid();
        }

        if (position.qty < order.qty) {
            order.qty = position.qty;
        }

        MarketProcess.updateMarketFundingFeeRate(symbolProps.code);
        MarketProcess.updatePoolBorrowingFeeRate(symbolProps.stakeToken, position.isLong, order.marginToken);

        uint256 executionPrice = _getExecutionPrice(order, symbolProps.indexToken);

        position.decreasePosition(
            DecreasePositionProcess.DecreasePositionParams(
                orderId,
                order.symbol,
                false,
                false,
                order.marginToken,
                order.qty,
                executionPrice
            )
        );
        Account.load(order.account).delOrder(orderId);
        emit OrderFilledEvent(orderId, order, block.timestamp, executionPrice);
    }

    function _validateGasFeeLimitAndInitialMargin(
        Account.Props storage accountProps,
        IOrder.PlaceOrderParams calldata params
    ) internal returns (uint256, bool) {
        AppConfig.ChainConfig memory chainConfig = AppConfig.getChainConfig();
        uint256 configGasFeeLimit = Order.PositionSide.INCREASE == params.posSide
            ? chainConfig.placeIncreaseOrderGasFeeLimit
            : chainConfig.placeDecreaseOrderGasFeeLimit;
        GasProcess.validateExecutionFeeLimit(params.executionFee, configGasFeeLimit);
        if (
            params.isNativeToken &&
            params.posSide == Order.PositionSide.INCREASE &&
            !params.isCrossMargin &&
            params.orderMargin >= params.executionFee
        ) {
            return (params.orderMargin - params.executionFee, true);
        }
        require(msg.value == params.executionFee, "place order with execution fee error!");
        AssetsProcess.depositToVault(
            AssetsProcess.DepositParams(
                accountProps.owner,
                chainConfig.wrapperToken,
                params.executionFee,
                params.isCrossMargin ? AssetsProcess.DepositFrom.MANUAL : AssetsProcess.DepositFrom.ORDER,
                true
            )
        );
        return (params.orderMargin, !params.isCrossMargin);
    }

    function _validateBatchGasFeeLimit(
        Account.Props storage accountProps,
        IOrder.PlaceOrderParams calldata params
    ) internal returns (uint256, bool) {
        AppConfig.ChainConfig memory chainConfig = AppConfig.getChainConfig();
        uint256 configGasFeeLimit = Order.PositionSide.INCREASE == params.posSide
            ? chainConfig.placeIncreaseOrderGasFeeLimit
            : chainConfig.placeDecreaseOrderGasFeeLimit;
        GasProcess.validateExecutionFeeLimit(params.executionFee, configGasFeeLimit);
        if (
            params.isNativeToken &&
            params.posSide == Order.PositionSide.INCREASE &&
            !params.isCrossMargin &&
            params.orderMargin >= params.executionFee
        ) {
            accountProps.subTokenIgnoreUsedAmount(
                chainConfig.wrapperToken,
                params.executionFee,
                Account.UpdateSource.CHARGE_EXECUTION_FEE
            );
            return (params.orderMargin - params.executionFee, true);
        }
        require(msg.value == params.executionFee, "place order with execution fee error!");
        AssetsProcess.depositToVault(
            AssetsProcess.DepositParams(
                accountProps.owner,
                chainConfig.wrapperToken,
                params.executionFee,
                AssetsProcess.DepositFrom.MANUAL,
                true
            )
        );
        return (params.orderMargin, false);
    }
}
