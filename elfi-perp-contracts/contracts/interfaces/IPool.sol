// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/OracleProcess.sol";
import "../storage/LpPool.sol";
import "../storage/UsdPool.sol";
import "../storage/Mint.sol";
import "../storage/Redeem.sol";

interface IPool {

    struct PoolInfo {
        address stakeToken;
        string stakeTokenName;
        address baseToken;
        bytes32 symbol;
        MintTokenBalance baseTokenBalance;
        address[] stableTokens;
        MintTokenBalance[] stableTokenBalances;
        uint256 poolValue;
        uint256 availableLiquidity;
        int256 poolPnl;
        uint256 totalSupply;
        LpPool.BorrowingFee borrowingFee;
        uint256 apr;
        uint256 totalClaimedRewards;
    }

    struct MintTokenBalance {
        uint256 amount;
        uint256 liability;
        uint256 holdAmount;
        int256 unsettledAmount;
        uint256 lossAmount;
        address[] collateralTokens;
        uint256[] collateralAmounts;
    }

    struct UsdPoolInfo {
        address[] stableTokens;
        UsdPool.TokenBalance[] stableTokenBalances;
        uint256[] stableTokenMaxWithdraws;
        uint256 poolValue;
        uint256 totalSupply;
        uint256[] tokensAvailableLiquidity;
        UsdPool.BorrowingFee[] borrowingFees;
        uint256 apr;
        uint256 totalClaimedRewards;
    }

    function getPool(address stakeToken) external view returns (PoolInfo memory);

    function getUsdPool() external view returns (UsdPoolInfo memory);

    function getPoolWithOracle(address stakeToken, OracleProcess.OracleParam[] calldata oracles) external view returns (PoolInfo memory);

    function getUsdPoolWithOracle(OracleProcess.OracleParam[] calldata oracles) external view returns (UsdPoolInfo memory);

    function getAllPools(OracleProcess.OracleParam[] calldata oracles) external view returns (PoolInfo[] memory);
}
