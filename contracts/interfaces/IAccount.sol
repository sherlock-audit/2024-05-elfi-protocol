// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/AssetsProcess.sol";
import "../process/OracleProcess.sol";
import "../storage/Withdraw.sol";
import "../storage/Account.sol";

interface IAccount {

    struct AccountInfo {
        address owner;
        Account.TokenBalance[] tokenBalances;
        address[] tokens;
        bytes32[] positions;
        uint256 portfolioNetValue;
        uint256 totalUsedValue;
        int256 availableValue;
        uint256 orderHoldInUsd;
        int256 crossMMR;
        int256 crossNetValue;
        uint256 totalMM;
    }

    function deposit(address token, uint256 amount) external payable;

    function createWithdrawRequest(address token, uint256 amount) external;

    function executeWithdraw(uint256 requestId, OracleProcess.OracleParam[] calldata oracles) external;

    function cancelWithdraw(uint256 requestId, bytes32 reasonCode) external;
    
    function batchUpdateAccountToken(AssetsProcess.UpdateAccountTokenParams calldata params) external;

    function getAccountInfo(address account) external view returns (AccountInfo memory);

    function getAccountInfoWithOracles(address account, OracleProcess.OracleParam[] calldata oracles) external view returns (AccountInfo memory);
}
