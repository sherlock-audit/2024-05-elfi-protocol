// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/ILiquidation.sol";
import "../process/LiquidationProcess.sol";
import "../process/GasProcess.sol";
import "../process/AssetsProcess.sol";
import "../storage/InsuranceFund.sol";
import "../storage/RoleAccessControl.sol";

contract LiquidationFacet is ILiquidation {
    using InsuranceFund for InsuranceFund.Props;

    function liquidationPosition(bytes32 positionKey, OracleProcess.OracleParam[] calldata oracles) external override {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        uint256 startGas = gasleft();
        OracleProcess.setOraclePrice(oracles);
        LiquidationProcess.liquidationIsolatePosition(positionKey);
        OracleProcess.clearOraclePrice();
        GasProcess.addLossExecutionFee(startGas);
    }

    function liquidationAccount(address account, OracleProcess.OracleParam[] calldata oracles) external override {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        uint256 startGas = gasleft();
        OracleProcess.setOraclePrice(oracles);
        LiquidationProcess.liquidationCrossPositions(account);
        OracleProcess.clearOraclePrice();
        GasProcess.addLossExecutionFee(startGas);
    }

    function liquidationLiability(CleanLiabilityParams calldata params) external override {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        uint256 startGas = gasleft();
        LiquidationProcess.liquidationLiability(params);
        GasProcess.addLossExecutionFee(startGas);
    }

    function callLiabilityClean(uint256 cleanId) external override {
        LiabilityClean.LiabilityCleanInfo memory cleanInfo = LiabilityClean.getCleanInfo(cleanId);
        if (cleanInfo.account == address(0)) {
            revert Errors.CallLiabilityCleanNotExists(cleanId);
        }
        for (uint256 i; i < cleanInfo.liabilityTokens.length; i++) {
            AssetsProcess.depositToVault(
                AssetsProcess.DepositParams(
                    msg.sender,
                    cleanInfo.liabilityTokens[i],
                    cleanInfo.liabilities[i],
                    AssetsProcess.DepositFrom.MANUAL,
                    false
                )
            );
        }
        for (uint256 i; i < cleanInfo.collaterals.length; i++) {
            VaultProcess.transferOut(
                IVault(address(this)).getPortfolioVaultAddress(),
                cleanInfo.collaterals[i],
                msg.sender,
                cleanInfo.collateralsAmount[i]
            );
        }
        LiabilityClean.removeClean(cleanId);
        emit LiabilityCleanSuccessful(cleanId);
    }

    function getInsuranceFunds(address stakeToken, address token) external view override returns (uint256) {
        return InsuranceFund.load(stakeToken).getTokenFee(token);
    }

    function getAllCleanInfos() external view override returns (LiabilityClean.LiabilityCleanInfo[] memory) {
        return LiabilityClean.getAllCleanInfo();
    }
}
