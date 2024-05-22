// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/OracleProcess.sol";
import "../storage/Position.sol";
import "../storage/UpdatePositionMargin.sol";
import "../storage/UpdateLeverage.sol";

interface IPosition {

    /// @dev UpdatePositionMarginParams struct used for updating position margin requests
    ///
    /// @param positionKey the unique key of the position
    /// @param isAdd whether the request is an additional margin
    /// @param isNativeToken whether the add margin is ETH
    /// @param marginToken the address of margin token
    /// @param updateMarginAmount the changed margin in tokens, only for isolated positions
    /// @param executionFee the execution fee for keeper
    struct UpdatePositionMarginParams {
        bytes32 positionKey;
        bool isAdd;
        bool isNativeToken;
        address marginToken;
        uint256 updateMarginAmount;
        uint256 executionFee;
    }

    /// @dev UpdateLeverageParams struct used for updating position leverage requests
    ///
    /// @param symbol the market to which the position belongs
    /// @param isLong  whether the direction of the position is long 
    /// @param isNativeToken whether the margin is ETH
    /// @param isCrossMargin whether it is a cross-margin position
    /// @param leverage the new leverage of the position
    /// @param marginToken the address of margin token
    /// @param addMarginAmount the add margin in tokens when reducing leverage, only for isolated positions
    /// @param executionFee the execution fee for keeper
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
