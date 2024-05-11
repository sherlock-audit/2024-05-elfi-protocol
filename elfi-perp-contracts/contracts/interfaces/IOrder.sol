// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/OrderProcess.sol";
import "../process/OracleProcess.sol";
import "../storage/Order.sol";

interface IOrder {
    struct PlaceOrderParams {
        bytes32 symbol;
        bool isCrossMargin;
        bool isNativeToken;
        Order.Side orderSide;
        Order.PositionSide posSide;
        Order.Type orderType;
        Order.StopType stopType;
        address marginToken;
        uint256 qty; // decrease only
        uint256 orderMargin; // increase only
        uint256 leverage;
        uint256 triggerPrice;
        uint256 acceptablePrice;
        uint256 executionFee;
        uint256 placeTime;
    }

    struct AccountOrder {
        uint256 orderId;
        Order.OrderInfo orderInfo;
    }

    function createOrderRequest(PlaceOrderParams calldata params) external payable;

    function batchCreateOrderRequest(PlaceOrderParams[] calldata params) external payable;

    function executeOrder(uint256 orderId, OracleProcess.OracleParam[] calldata oracles) external;

    function cancelOrder(uint256 orderId, bytes32 reasonCode) external;

    function getAccountOrders(address account) external view returns (AccountOrder[] memory);
}
