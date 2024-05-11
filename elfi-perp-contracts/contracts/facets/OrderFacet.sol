// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/IOrder.sol";
import "../interfaces/IAccount.sol";
import "../process/AssetsProcess.sol";
import "../process/OrderProcess.sol";
import "../process/CancelOrderProcess.sol";
import "../process/GasProcess.sol";
import "../storage/RoleAccessControl.sol";

contract OrderFacet is IOrder, ReentrancyGuard {
    using SafeCast for uint256;
    using Account for Account.Props;
    using Order for Order.Props;

    function createOrderRequest(PlaceOrderParams calldata params) external payable override nonReentrant {
        address account = msg.sender;
        if (params.posSide == Order.PositionSide.INCREASE && !params.isCrossMargin) {
            require(!params.isNativeToken || msg.value == params.orderMargin, "Deposit native token amount error!");
            AssetsProcess.depositToVault(
                AssetsProcess.DepositParams(
                    account,
                    params.marginToken,
                    params.orderMargin,
                    AssetsProcess.DepositFrom.ORDER,
                    params.isNativeToken
                )
            );
        }
        Account.Props storage accountProps = Account.loadOrCreate(account);
        OrderProcess.createOrderRequest(accountProps, params, true);
    }

    function batchCreateOrderRequest(PlaceOrderParams[] calldata params) external payable override nonReentrant {
        address account = msg.sender;
        Account.Props storage accountProps = Account.loadOrCreate(account);
        uint256 totalExecutionFee;
        AppConfig.ChainConfig memory chainConfig = AppConfig.getChainConfig();
        bool isCrossMargin = params[0].isCrossMargin;
        for (uint256 i; i < params.length; i++) {
            if (params[i].posSide == Order.PositionSide.INCREASE) {
                revert Errors.OnlyDecreaseOrderSupported();
            }
            if (isCrossMargin != params[i].isCrossMargin) {
                revert Errors.MarginModeError();
            }
            GasProcess.validateExecutionFeeLimit(params[i].executionFee, chainConfig.placeDecreaseOrderGasFeeLimit);
            OrderProcess.createOrderRequest(accountProps, params[i], false);
            totalExecutionFee += params[i].executionFee;
        }
        require(msg.value == totalExecutionFee, "Batch place order with execution fee error!");
        AssetsProcess.depositToVault(
            AssetsProcess.DepositParams(
                accountProps.owner,
                chainConfig.wrapperToken,
                totalExecutionFee,
                isCrossMargin ? AssetsProcess.DepositFrom.MANUAL : AssetsProcess.DepositFrom.ORDER,
                true
            )
        );
    }

    function executeOrder(uint256 orderId, OracleProcess.OracleParam[] calldata oracles) external override {
        uint256 startGas = gasleft();
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        Order.OrderInfo memory order = Order.get(orderId);
        if (order.account == address(0)) {
            revert Errors.OrderNotExists(orderId);
        }
        OracleProcess.setOraclePrice(oracles);
        OrderProcess.executeOrder(orderId, order);
        OracleProcess.clearOraclePrice();
        GasProcess.processExecutionFee(
            GasProcess.PayExecutionFeeParams(
                order.isExecutionFeeFromTradeVault
                    ? IVault(address(this)).getTradeVaultAddress()
                    : IVault(address(this)).getPortfolioVaultAddress(),
                order.executionFee,
                startGas,
                msg.sender,
                order.account
            )
        );
    }

    function cancelOrder(uint256 orderId, bytes32 reasonCode) external override {
        uint256 startGas = gasleft();
        Order.OrderInfo memory order = Order.get(orderId);
        if (order.account == address(0)) {
            revert Errors.OrderNotExists(orderId);
        }
        bool isKeeper = RoleAccessControl.hasRole(RoleAccessControl.ROLE_KEEPER);
        if (!isKeeper && order.account != msg.sender) {
            revert Errors.OrderNotExists(orderId);
        }

        CancelOrderProcess.cancelOrder(orderId, order, reasonCode);

        if (isKeeper) {
            GasProcess.processExecutionFee(
                GasProcess.PayExecutionFeeParams(
                    order.isExecutionFeeFromTradeVault
                        ? IVault(address(this)).getTradeVaultAddress()
                        : IVault(address(this)).getPortfolioVaultAddress(),
                    order.executionFee,
                    startGas,
                    msg.sender,
                    order.account
                )
            );
        } else {
            VaultProcess.transferOut(
                order.isExecutionFeeFromTradeVault
                    ? IVault(address(this)).getTradeVaultAddress()
                    : IVault(address(this)).getPortfolioVaultAddress(),
                AppConfig.getChainConfig().wrapperToken,
                address(this),
                order.executionFee
            );
            VaultProcess.withdrawEther(order.account, order.executionFee);
        }
    }

    receive() external payable {}

    function getAccountOrders(address account) external view override returns (AccountOrder[] memory result) {
        Account.Props storage accountProps = Account.load(account);
        if (accountProps.isExists()) {
            uint256[] memory orders = accountProps.getOrders();
            result = new AccountOrder[](orders.length);
            Order.Props storage orderStorage = Order.load();
            for (uint256 i; i < orders.length; i++) {
                result[i].orderId = orders[i];
                result[i].orderInfo = orderStorage.get(orders[i]);
            }
        }
    }
}
