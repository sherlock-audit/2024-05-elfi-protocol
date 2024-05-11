// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/AccountProcess.sol";
import "../process/RebalanceProcess.sol";
import "../process/OracleProcess.sol";
import "../storage/Withdraw.sol";

interface ISwap {
    struct SwapParams {
        address fromTokenAddress;
        address[] fromTokens;
        uint256[] fromAmounts;
        uint256[] minToTokenAmounts;
        address toToken;
        address toTokenAddress;
        uint256 toTokenAmount;
    }

    struct SwapSingleParam {
        address fromTokenAddress;
        address fromToken;
        uint256 fromAmount;
        uint256 minToTokenAmount;
        address toToken;
        address toTokenAddress;
    }

    struct SwapResult {
        address[] fromTokens;
        uint256[] reduceFromAmounts;
        address toToken;
        uint256 toTokenAmount;
        uint256 expectToTokenAmount;
    }

    struct SwapSingleResult {
        address fromToken;
        uint256 reduceFromAmount;
        address toToken;
        uint256 toTokenAmount;
    }

    function swapPortfolioToPayLiability(
        address[] calldata accounts,
        address[][] calldata accountTokens,
        OracleProcess.OracleParam[] calldata oracles
    ) external;
}
