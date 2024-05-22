// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IVault.sol";
import "./VaultProcess.sol";
import "../storage/Account.sol";
import "../storage/Order.sol";

/// @title CancelOrderProcess
/// @dev Library to handle cancellation of orders
library CancelOrderProcess {
    using Order for Order.Props;
    using Account for Account.Props;

    bytes32 public constant CANCEL_ORDER_LIQUIDATION = bytes32(abi.encode("CANCEL_WITH_LIQUIDATION"));
    bytes32 public constant CANCEL_ORDER_AUTO_REDUCE = bytes32(abi.encode("CANCEL_WITH_AUTO_REDUCE"));
    bytes32 public constant CANCEL_ORDER_POSITION_CLOSE = bytes32(abi.encode("CANCEL_WITH_POSITION_CLOSE"));

    event CancelOrderEvent(uint256 indexed orderId, Order.OrderInfo data, bytes32 reasonCode);

    /// @dev cancel all cross-margin orders for the user
    /// when the user's cross-margin position is liquidated, all of the user's cross-margin orders will be canceled.
    ///
    /// @param account the user account
    /// @param reasonCode the reason for cancellation
    function cancelAllCrossOrders(address account, bytes32 reasonCode) internal {
        Account.Props storage accountProps = Account.load(account);
        uint256[] memory orders = accountProps.getOrders();
        if (orders.length == 0) {
            return;
        }
        Order.Props storage orderProps = Order.load();
        for (uint256 i; i < orders.length; i++) {
            Order.OrderInfo memory order = orderProps.get(orders[i]);
            if (order.isCrossMargin) {
                orderProps.remove(orders[i]);
                accountProps.delOrder(orders[i]);
                if (Order.PositionSide.INCREASE == order.posSide) {
                    accountProps.subOrderHoldInUsd(order.orderMargin);
                }
                emit CancelOrderEvent(orders[i], order, reasonCode);
            }
        }
    }

    /// @dev cancel the market isolated orders for the user
    ///
    /// @param account the user account
    /// @param symbol the market
    /// @param marginToken order margin token
    /// @param reasonCode the reason for cancellation
    function cancelSymbolOrders(address account, bytes32 symbol, address marginToken, bytes32 reasonCode) internal {
        Account.Props storage accountProps = Account.load(account);
        uint256[] memory orders = accountProps.getOrders();
        if (orders.length == 0) {
            return;
        }
        Order.Props storage orderProps = Order.load();
        for (uint256 i; i < orders.length; i++) {
            Order.OrderInfo memory order = orderProps.get(orders[i]);
            if (order.symbol == symbol && order.marginToken == marginToken && order.isCrossMargin == false) {
                orderProps.remove(orders[i]);
                accountProps.delOrder(orders[i]);
                if (Order.PositionSide.INCREASE == order.posSide) {
                    VaultProcess.transferOut(
                        IVault(address(this)).getTradeVaultAddress(),
                        order.marginToken,
                        order.account,
                        order.orderMargin
                    );
                }
                emit CancelOrderEvent(orders[i], order, reasonCode);
            }
        }
    }

    /// @dev cancel the stop orders for the user
    ///
    /// @param account the user account
    /// @param symbol the market
    /// @param marginToken order margin token
    /// @param isCrossMargin whether is cross-margin order
    /// @param reasonCode the reason for cancellation
    /// @param excludeOrder excluded order id
    function cancelStopOrders(
        address account,
        bytes32 symbol,
        address marginToken,
        bool isCrossMargin,
        bytes32 reasonCode,
        uint256 excludeOrder
    ) external {
        Account.Props storage accountProps = Account.load(account);
        uint256[] memory orderIds = accountProps.getAllOrders();
        if (orderIds.length == 0) {
            return;
        }
        Order.Props storage orderPros = Order.load();
        for (uint256 i; i < orderIds.length; i++) {
            if (orderIds[i] == excludeOrder) {
                continue;
            }
            Order.OrderInfo memory orderInfo = orderPros.get(orderIds[i]);
            if (
                orderInfo.symbol == symbol &&
                orderInfo.marginToken == marginToken &&
                Order.Type.STOP == orderInfo.orderType &&
                orderInfo.isCrossMargin == isCrossMargin
            ) {
                accountProps.delOrder(orderIds[i]);
                orderPros.remove(orderIds[i]);
                emit CancelOrderEvent(orderIds[i], orderInfo, reasonCode);
            }
        }
    }

    /// @dev cancel a single order
    ///
    /// @param orderId the unique id of the order
    /// @param order Order.OrderInfo
    /// @param reasonCode the reason for cancellation
    function cancelOrder(uint256 orderId, Order.OrderInfo memory order, bytes32 reasonCode) external {
        Account.Props storage accountProps = Account.load(order.account);
        accountProps.delOrder(orderId);
        Order.remove(orderId);
        if (Order.PositionSide.INCREASE == order.posSide && order.isCrossMargin) {
            accountProps.subOrderHoldInUsd(order.orderMargin);
        } else if (Order.PositionSide.INCREASE == order.posSide && !order.isCrossMargin) {
            VaultProcess.transferOut(
                IVault(address(this)).getTradeVaultAddress(),
                order.marginToken,
                order.account,
                order.orderMargin
            );
        }
        emit CancelOrderEvent(orderId, order, reasonCode);
    }
}
