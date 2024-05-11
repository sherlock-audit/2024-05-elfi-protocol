// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/OracleProcess.sol";
import "../storage/Position.sol";
import "../storage/UpdatePositionMargin.sol";
import "../storage/UpdateLeverage.sol";

interface IPosition {
    struct UpdatePositionMarginParams {
        bytes32 positionKey;
        bool isAdd;
        bool isNativeToken;
        address marginToken;
        uint256 updateMarginAmount;
        uint256 executionFee;
    }

    struct UpdateLeverageParams {
        bytes32 symbol;
        bool isLong;
        bool isNativeToken;
        bool isCrossMargin;
        uint256 leverage;
        address marginToken;
        uint256 addMarginAmount;
        uint256 executionFee;
    }

    struct PositionInfo {
        Position.Props position;
        uint256 liquidationPrice;
        uint256 currentTimestamp;
    }

    function createUpdatePositionMarginRequest(UpdatePositionMarginParams calldata params) external payable;

    function executeUpdatePositionMarginRequest(
        uint256 requestId,
        OracleProcess.OracleParam[] calldata oracles
    ) external;

    function cancelUpdatePositionMarginRequest(uint256 orderId, bytes32 reasonCode) external;

    function createUpdateLeverageRequest(UpdateLeverageParams calldata params) external payable;

    function executeUpdateLeverageRequest(uint256 requestId, OracleProcess.OracleParam[] calldata oracles) external;

    function cancelUpdateLeverageRequest(uint256 orderId, bytes32 reasonCode) external;

    function autoReducePositions(bytes32[] calldata positionKeys) external;

    function getAllPositions(address account) external view returns (PositionInfo[] memory);

    function getSinglePosition(
        address account,
        bytes32 symbol,
        address marginToken,
        bool isCrossMargin
    ) external pure returns (Position.Props memory);
}
