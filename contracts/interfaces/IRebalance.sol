// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/OracleProcess.sol";

interface IRebalance {
    struct RebalancePortfolioParams {
        address token;
        bool isBaseToken;
        address[] stakeTokens;
    }

    struct RebalancePortfolioToPoolParams {
        address token;
        bool isBaseToken;
        uint256 rebalanceToLimitAmount;
        address[] stakeTokens;
        address[] autoSwapUsers;
    }

    struct TransferTokenParams {
        address stakeToken;
        address[] tokens;
        uint256[] transferAmounts;
    }

    struct RebalancePoolStableTokenParams {
        address stakeToken;
        bool swapToBase;
        address[] stableTokens;
        int256[] changedStableAmount;
        int256[] changedStableLossAmount;
        uint256[] transferToBaseTokenAmount;
        uint256[] transferToStableTokenAmount;
        uint256[] usdSettleAmount;
        uint256[] usdAddAmount;
    }

    function autoRebalance(OracleProcess.OracleParam[] calldata oracles) external;

    // function rebalancePortfolio(RebalancePortfolioParams[] calldata params) external;

    // function rebalancePortfolioToPool(RebalancePortfolioToPoolParams calldata params) external;

    // function transferUnsettleToken(TransferTokenParams[] calldata params) external;

    // function rebalancePoolStableTokens(RebalancePoolStableTokenParams[] calldata params) external;
}
