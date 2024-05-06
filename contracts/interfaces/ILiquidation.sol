// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/OracleProcess.sol";
import "../storage/LiabilityClean.sol";

interface ILiquidation {

    struct CleanLiabilityParams {
        address account;
        address liabilityToken;
        uint256 liability;
        address[] payTokens;
        uint256[] payAmounts;
    }

    event LiabilityCleanSuccessful(uint256 cleanId);

    function liquidationPosition(bytes32 positionKey, OracleProcess.OracleParam[] calldata oracles) external;

    function liquidationAccount(address account, OracleProcess.OracleParam[] calldata oracles) external;

    function liquidationLiability(CleanLiabilityParams calldata params) external;

    function callLiabilityClean(uint256 cleanId) external;

    function getInsuranceFunds(address stakeToken, address token) external view returns (uint256);

    function getAllCleanInfos() external view returns (LiabilityClean.LiabilityCleanInfo[] memory);

}
