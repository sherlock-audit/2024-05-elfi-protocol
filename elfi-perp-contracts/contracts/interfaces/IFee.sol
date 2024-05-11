// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/OracleProcess.sol";
import "../process/FeeQueryProcess.sol";

interface IFee {
    struct AccountFeeRewards {
        address account;
        address[] stakeTokens;
        address[] tokens;
        uint256[] rewards;
    }

    struct AccountUsdFeeReward {
        address account;
        address stakeToken;
        uint256 reward;
    }

    function distributeFeeRewards(uint256 interval, OracleProcess.OracleParam[] calldata oracles) external;

    function createClaimRewards(address claimUsdToken, uint256 executionFee) external payable;

    function executeClaimRewards(uint256 requestId, OracleProcess.OracleParam[] calldata oracles) external;

    function getPoolTokenFee(address stakeToken, address token) external view returns (uint256);

    function getCumulativeRewardsPerStakeToken(address stakeToken) external view returns (uint256);

    function getMarketTokenFee(bytes32 symbol, address token) external view returns (uint256);

    function getStakingTokenFee(address stakeToken, address token) external view returns (uint256);

    function getDaoTokenFee(address stakeToken, address token) external view returns (uint256);

    function getAccountFeeRewards(address account) external view returns (AccountFeeRewards memory);

    function getAccountUsdFeeReward(address account) external view returns (AccountUsdFeeReward memory);

    function getAccountsFeeRewards(address[] calldata accounts) external view returns (AccountFeeRewards[] memory);
}
