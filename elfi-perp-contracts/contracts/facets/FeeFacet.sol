// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IFee.sol";
import "../storage/RoleAccessControl.sol";
import "../process/FeeQueryProcess.sol";
import "../process/FeeRewardsProcess.sol";
import "../process/ClaimRewardsProcess.sol";
import "../process/OracleProcess.sol";
import "../process/GasProcess.sol";

contract FeeFacet is IFee {
    function distributeFeeRewards(uint256 interval, OracleProcess.OracleParam[] calldata oracles) external override {
        uint256 startGas = gasleft();
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        OracleProcess.setOraclePrice(oracles);
        FeeRewardsProcess.distributeFeeRewards(interval);
        OracleProcess.clearOraclePrice();
        GasProcess.addLossExecutionFee(startGas);
    }

    function createClaimRewards(address claimUsdToken, uint256 executionFee) external payable override {
        ClaimRewardsProcess.createClaimRewards(msg.sender, claimUsdToken, executionFee);
    }

    function executeClaimRewards(uint256 requestId, OracleProcess.OracleParam[] calldata oracles) external override {
        uint256 startGas = gasleft();
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        ClaimRewards.Request memory request = ClaimRewards.get(requestId);
        if (request.account == address(0)) {
            revert Errors.ClaimRewardsRequestNotExists();
        }
        OracleProcess.setOraclePrice(oracles);
        ClaimRewardsProcess.claimRewards(requestId, request);
        OracleProcess.clearOraclePrice();
        GasProcess.processExecutionFee(
            GasProcess.PayExecutionFeeParams(
                IVault(address(this)).getPortfolioVaultAddress(),
                request.executionFee,
                startGas,
                msg.sender,
                request.account
            )
        );
    }

    function cancelClaimRewards(uint256 requestId, bytes32 reasonCode) external {
        uint256 startGas = gasleft();
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        ClaimRewards.Request memory request = ClaimRewards.get(requestId);
        if (request.account == address(0)) {
            revert Errors.ClaimRewardsRequestNotExists();
        }
        ClaimRewardsProcess.cancelClaimRewards(requestId, request, reasonCode);
        GasProcess.processExecutionFee(
            GasProcess.PayExecutionFeeParams(
                IVault(address(this)).getPortfolioVaultAddress(),
                request.executionFee,
                startGas,
                msg.sender,
                request.account
            )
        );
    }

    function getPoolTokenFee(address stakeToken, address token) external view override returns (uint256) {
        return FeeQueryProcess.getPoolTokenFeeAmount(stakeToken, token);
    }

    function getCumulativeRewardsPerStakeToken(address stakeToken) external view override returns (uint256) {
        return FeeQueryProcess.getCumulativeRewardsPerStakeToken(stakeToken);
    }

    function getMarketTokenFee(bytes32 symbol, address token) external view override returns (uint256) {
        return FeeQueryProcess.getMarketTokenFeeAmount(symbol, token);
    }

    function getStakingTokenFee(address stakeToken, address token) external view override returns (uint256) {
        return FeeQueryProcess.getStakingTokenFee(stakeToken, token);
    }

    function getDaoTokenFee(address stakeToken, address token) external view override returns (uint256) {
        return FeeQueryProcess.getDaoTokenFee(stakeToken, token);
    }

    function getAccountFeeRewards(address account) external view override returns (AccountFeeRewards memory) {
        return FeeQueryProcess.getAccountFeeRewards(account);
    }

    function getAccountUsdFeeReward(address account) external view override returns (AccountUsdFeeReward memory) {
        return FeeQueryProcess.getAccountUsdFeeReward(account);
    }

    function getAccountsFeeRewards(
        address[] calldata accounts
    ) external view override returns (AccountFeeRewards[] memory) {
        AccountFeeRewards[] memory result = new AccountFeeRewards[](accounts.length);
        for (uint256 i; i < accounts.length; i++) {
            result[i] = FeeQueryProcess.getAccountFeeRewards(accounts[i]);
        }
        return result;
    }
}
