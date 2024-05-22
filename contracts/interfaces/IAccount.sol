// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/AssetsProcess.sol";
import "../process/OracleProcess.sol";
import "../storage/Withdraw.sol";
import "../storage/Account.sol";

interface IAccount {

    /// @dev Struct representing the account information.
    /// @param owner the address of the trade account.
    /// @param tokenBalances Account.TokenBalance[].
    /// @param tokens Set of tokens associated with the trade account.
    /// @param positions Set of active position IDs.
    /// @param portfolioNetValue The net value of all collateral in the account, in USD.
    /// @param totalUsedValue The total used value in USD, including portions used for positions and orders. 
    /// @param availableValue The amount that can be used to increase positions or make withdrawals in USD.
    /// @param orderHoldInUsd The value held by the account's active orders, in USD
    /// @param crossMMR If the overall account risk ratio drops to 100%, it triggers the liquidation of all positions and collateral.
    /// @param crossNetValue In The account net value is composed of collateral, position margin, and position profit and loss, in USD.
    /// @param totalMM The total sum of all maintenance margins
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
