// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "./VaultProcess.sol";
import "../interfaces/IVault.sol";
import "../storage/AppConfig.sol";
import "../storage/CommonData.sol";

library GasProcess {
    struct PayExecutionFeeParams {
        address from;
        uint256 userExecutionFee;
        uint256 startGas;
        address keeper;
        address account;
    }

    function processExecutionFee(PayExecutionFeeParams memory cache) external {
        uint256 usedGas = cache.startGas - gasleft();
        uint256 executionFee = usedGas * tx.gasprice;
        uint256 refundFee;
        uint256 lossFee;
        if (executionFee > cache.userExecutionFee) {
            executionFee = cache.userExecutionFee;
            lossFee = executionFee - cache.userExecutionFee;
        } else {
            refundFee = cache.userExecutionFee - executionFee;
        }
        VaultProcess.transferOut(
            cache.from,
            AppConfig.getChainConfig().wrapperToken,
            address(this),
            cache.userExecutionFee
        );
        VaultProcess.withdrawEther(cache.keeper, executionFee);
        if (refundFee > 0) {
            VaultProcess.withdrawEther(cache.account, refundFee);
        }
        if (lossFee > 0) {
            CommonData.addLossExecutionFee(lossFee);
        }
    }

    function addLossExecutionFee(uint256 startGas) external {
        uint256 usedGas = startGas - gasleft();
        uint256 executionFee = usedGas * tx.gasprice;
        if (executionFee > 0) {
            CommonData.addLossExecutionFee(executionFee);
        }
    }

    function validateExecutionFeeLimit(uint256 executionFee, uint256 gasLimit) external view {
        if (executionFee < gasLimit * tx.gasprice) {
            revert Errors.ExecutionFeeNotEnough();
        }
    }
}
