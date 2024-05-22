// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/OrderProcess.sol";
import "../process/OracleProcess.sol";
import "../storage/Order.sol";

interface IOrder {

    /// @dev PlaceOrderParams struct used for placing order
    ///
    /// @param symbol the market to which the order belongs
    /// @param isCrossMargin whether it is a cross-margin order
    /// @param isNativeToken whether the margin is ETH
    /// @param orderSide the direction of the order, long or short   
    /// @param posSide the direction of the position, increase or decrease
    /// @param stopType the type of stop-loss or take-profit order
    /// @param marginToken the address of margin token
    /// @param qty the size of the position, used only for reducing positions
    /// @param orderMargin the margin required for placing the order, used only for increasing positions
    /// @param leverage the leverage of the order, using a global leverage mode, all orders and positions with the same (symbol, isCrossMargin, orderSide) have the same leverage
    /// @param triggerPrice the trigger price of the order, for limit & stop order
    /// @param acceptablePrice the worst acceptable execution price
    /// @param executionFee the execution fee for keeper
    /// @param placeTime the time when the order is placed
    struct PlaceOrderParams {
        bytes32 symbol;
        bool isCrossMargin;
        bool isNativeToken;
        Order.Side orderSide;
        Order.PositionSide posSide;
        Order.Type orderType;
        Order.StopType stopType;
        address marginToken;
        uint256 qty; /// decrease only
        uint256 orderMargin; /// increase only
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
