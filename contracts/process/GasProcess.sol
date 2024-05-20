// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./VaultProcess.sol";
import "../interfaces/IVault.sol";
import "../storage/AppConfig.sol";
import "../storage/CommonData.sol";

library GasProcess {
    /// @dev Parameters for paying execution fees
    struct PayExecutionFeeParams {
        /// @dev Address from which the fee is paid
        address from;
        /// @dev the fee user payed
        uint256 userExecutionFee;
        /// @dev Gas at the start of the transaction
        uint256 startGas;
        /// @dev Address of the keeper
        address keeper;
        /// @dev User's account address for refund
        address account;
    }

    /// @dev Processes the execution fee for the first phase request
    /// @param cache Struct containing parameters for fee payment
    function processExecutionFee(PayExecutionFeeParams memory cache) external {
        /// @dev Calculates the gas used
        uint256 usedGas = cache.startGas - gasleft();
        /// @dev Calculates the execution fee based on gas used and gas price
        uint256 executionFee = usedGas * tx.gasprice;
        uint256 refundFee;
        uint256 lossFee;

        if (executionFee > cache.userExecutionFee) {
            executionFee = cache.userExecutionFee;
            lossFee = executionFee - cache.userExecutionFee;
        } else {
            /// @dev Calculates the refund fee if execution fee is less than user's fee
            refundFee = cache.userExecutionFee - executionFee;
        }

        /// @dev Transfers the user's execution fee to the contract
        VaultProcess.transferOut(
            cache.from,
            AppConfig.getChainConfig().wrapperToken,
            address(this),
            cache.userExecutionFee
        );

        /// @dev Withdraws the execution fee to the keeper
        VaultProcess.withdrawEther(cache.keeper, executionFee);

        if (refundFee > 0) {
            /// @dev Refunds the remaining fee to the user's account
            VaultProcess.withdrawEther(cache.account, refundFee);
        }

        if (lossFee > 0) {
            /// @dev Records the loss fee
            CommonData.addLossExecutionFee(lossFee);
        }
    }

    /// @dev Adds the loss execution fee to the common data
    /// @param startGas The gas at the start of the transaction
    function addLossExecutionFee(uint256 startGas) external {
        /// @dev Calculates the gas used
        uint256 usedGas = startGas - gasleft();
        /// @dev Calculates the execution fee based on gas used and gas price
        uint256 executionFee = usedGas * tx.gasprice;

        if (executionFee > 0) {
            /// @dev Records the execution fee as a loss
            CommonData.addLossExecutionFee(executionFee);
        }
    }

    /// @dev Validates if the execution fee is within the gas limit
    /// @param executionFee The calculated execution fee
    /// @param gasLimit The maximum gas limit allowed
    function validateExecutionFeeLimit(uint256 executionFee, uint256 gasLimit) external view {
        if (executionFee < gasLimit * tx.gasprice) {
            revert Errors.ExecutionFeeNotEnough();
        }
    }
}
