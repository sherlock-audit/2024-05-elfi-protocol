// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

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

    struct Props {
        mapping(uint256 => OrderInfo) orders;
    }

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
        uint256 leverage; //position leverage
        uint256 orderMargin;
        uint256 triggerPrice; // for limit & stop order
        uint256 acceptablePrice; //for market & stop order
        uint256 placeTime;
        uint256 executionFee;
        uint256 lastBlock;
    }

    function load() public pure returns (Props storage self) {
        bytes32 s = ORDER;
        assembly {
            self.slot := s
        }
    }

    function create(uint256 orderId) external view returns (OrderInfo storage) {
        Order.Props storage self = load();
        return self.orders[orderId];
    }

    function get(Order.Props storage self, uint256 orderId) external view returns (OrderInfo storage) {
        return self.orders[orderId];
    }

    function get(uint256 orderId) external view returns (OrderInfo storage) {
        Order.Props storage self = load();
        return self.orders[orderId];
    }

    function remove(Order.Props storage self, uint256 orderId) external {
        delete self.orders[orderId];
    }

    function remove(uint256 orderId) external {
        Order.Props storage self = load();
        delete self.orders[orderId];
    }

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
