// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title Order Storage
/// @dev Library for order storage and management 
library Order {
    bytes32 constant ORDER = keccak256(abi.encode("xyz.elfi.storage.Order"));

    enum PositionSide {
        NONE,
        INCREASE,
        DECREASE
    }

    enum Side {
        NONE,
        LONG,
        SHORT
    }

    enum Type {
        NONE,
        MARKET,
        LIMIT,
        STOP
    }

    enum StopType {
        NONE,
        STOP_LOSS,
        TAKE_PROFIT
    }

    /// @dev Struct representing the properties of the order storage
    struct Props {
        mapping(uint256 => OrderInfo) orders;
    }

    /// @dev Struct representing the order information
    /// @param account The address to whom the order belongs
    /// @param symbol The market to which the order belongs
    /// @param orderSide The direction of the order, long or short
    /// @param posSide The direction of the position, increase or decrease
    /// @param orderType The type of the order, market, limit, or stop
    /// @param stopType The type of stop-loss or take-profit order
    /// @param isCrossMargin Whether it is a cross-margin order
    /// @param isExecutionFeeFromTradeVault Whether the execution fee collected in the first phase is deposited to the Trade Vault
    /// @param marginToken The address of the margin token
    /// @param qty The size of the position, used only for reducing positions
    /// @param leverage The leverage of the order, using a global leverage mode, all orders and positions with the same (symbol, isCrossMargin, orderSide) have the same leverage
    /// @param orderMargin The margin required for placing the order, used only for increasing positions
    /// @param triggerPrice The trigger price of the order, for limit & stop order
    /// @param acceptablePrice The worst acceptable execution price
    /// @param placeTime The time when the order is placed
    /// @param executionFee The execution fee for the keeper
    /// @param lastBlock The block in which the order was placed
    struct OrderInfo {
        address account;
        bytes32 symbol;
        Side orderSide;
        PositionSide posSide;
        Type orderType;
        StopType stopType;
        bool isCrossMargin;
        bool isExecutionFeeFromTradeVault;
        address marginToken;
        uint256 qty;
        uint256 leverage; 
        uint256 orderMargin;
        uint256 triggerPrice; 
        uint256 acceptablePrice; 
        uint256 placeTime;
        uint256 executionFee;
        uint256 lastBlock;
    }

    /// @dev Loads the order properties from storage
    /// @return self Order.Props
    function load() public pure returns (Props storage self) {
        bytes32 s = ORDER;
        assembly {
            self.slot := s
        }
    }

    /// @dev Creates a new order with the given ID
    /// @param orderId The ID of the order to create
    /// @return Order.OrderInfo
    function create(uint256 orderId) external view returns (OrderInfo storage) {
        Order.Props storage self = load();
        return self.orders[orderId];
    }

    /// @dev Retrieves the order information for the given order ID
    /// @param self Order.Props
    /// @param orderId The ID of the order to retrieve
    /// @return Order.OrderInfo
    function get(Order.Props storage self, uint256 orderId) external view returns (OrderInfo storage) {
        return self.orders[orderId];
    }

    /// @dev Retrieves the order information for the given order ID
    /// @param orderId The ID of the order to retrieve
    /// @return Order.OrderInfo
    function get(uint256 orderId) external view returns (OrderInfo storage) {
        Order.Props storage self = load();
        return self.orders[orderId];
    }

    /// @dev Removes the order with the given ID
    /// @param self Order.Props
    /// @param orderId The ID of the order to remove
    function remove(Order.Props storage self, uint256 orderId) external {
        delete self.orders[orderId];
    }

    /// @dev Removes the order with the given ID
    /// @param orderId The ID of the order to remove
    function remove(uint256 orderId) external {
        Order.Props storage self = load();
        delete self.orders[orderId];
    }

    /// @dev Updates the leverage for all orders with the specified parameters
    /// @param orders The list of order IDs to update
    /// @param symbol The market symbol
    /// @param marginToken The margin token
    /// @param leverage The new leverage
    /// @param isLong Whether the orders are long
    /// @param isCrossMargin Whether the orders are cross-margin
    function updateAllOrderLeverage(
        uint256[] memory orders,
        bytes32 symbol,
        address marginToken,
        uint256 leverage,
        bool isLong,
        bool isCrossMargin
    ) external {
        Order.Props storage self = load();
        for (uint256 i; i < orders.length; i++) {
            Order.OrderInfo storage orderInfo = self.orders[orders[i]];
            bool isLongOrder = orderInfo.orderSide == Order.Side.LONG;
            if (
                orderInfo.isCrossMargin == isCrossMargin &&
                orderInfo.symbol == symbol &&
                orderInfo.marginToken == marginToken &&
                ((isLongOrder == isLong && orderInfo.posSide == Order.PositionSide.INCREASE) ||
                    (isLongOrder != isLong && orderInfo.posSide == Order.PositionSide.DECREASE))
            ) {
                orderInfo.leverage = leverage;
            }
        }
    }

    /// @dev Checks if there are other short position increase orders in the specified order list
    /// @param orders The list of order IDs to check
    /// @param symbol The market symbol
    /// @param marginToken The margin token
    /// @param isCrossMargin Whether the order is cross-margin
    /// @return True if there are other short position increase orders, false otherwise
    function hasOtherShortOrders(
        uint256[] memory orders,
        bytes32 symbol,
        address marginToken,
        bool isCrossMargin
    ) external view returns (bool) {
        Order.Props storage self = load();
        for (uint256 i; i < orders.length; i++) {
            Order.OrderInfo storage orderInfo = self.orders[orders[i]];
            if (
                orderInfo.symbol == symbol &&
                orderInfo.marginToken != marginToken &&
                orderInfo.isCrossMargin == isCrossMargin &&
                orderInfo.posSide == Order.PositionSide.INCREASE &&
                orderInfo.orderSide == Order.Side.SHORT
            ) {
                return true;
            }
        }
        return false;
    }
}
