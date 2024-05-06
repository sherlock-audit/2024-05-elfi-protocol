// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IAccount.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IWETH.sol";
import "../process/AssetsProcess.sol";
import "../process/AccountProcess.sol";
import "../storage/RoleAccessControl.sol";

contract AccountFacet is IAccount {
    using SafeERC20 for IERC20;
    using Account for Account.Props;
    using AccountProcess for Account.Props;

    function deposit(address token, uint256 amount) external payable override {
        if (amount == 0) {
            revert Errors.AmountZeroNotAllowed();
        }
        bool isNativeToken = token == address(0);
        if (isNativeToken && msg.value != amount) {
            revert Errors.AmountNotMatch(msg.value, amount);
        }
        if (!isNativeToken && !AppTradeTokenConfig.getTradeTokenConfig(token).isSupportCollateral) {
            revert Errors.OnlyCollateralSupported();
        }
        address account = msg.sender;
        AssetsProcess.deposit(
            AssetsProcess.DepositParams(
                account,
                isNativeToken ? AppConfig.getChainConfig().wrapperToken : token,
                amount,
                AssetsProcess.DepositFrom.MANUAL,
                isNativeToken
            )
        );
    }

    function createWithdrawRequest(address token, uint256 amount) external override {
        AddressUtils.validEmpty(token);
        if (amount == 0) {
            revert Errors.AmountZeroNotAllowed();
        }
        AssetsProcess.createWithdrawRequest(token, amount);
    }

    function executeWithdraw(uint256 requestId, OracleProcess.OracleParam[] calldata oracles) external override {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        Withdraw.Request memory request = Withdraw.get(requestId);
        if (request.account == address(0)) {
            revert Errors.WithdrawRequestNotExists();
        }
        OracleProcess.setOraclePrice(oracles);
        AssetsProcess.executeWithdraw(requestId, request);
        OracleProcess.clearOraclePrice();
    }

    function cancelWithdraw(uint256 requestId, bytes32 reasonCode) external override {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        Withdraw.Request memory request = Withdraw.get(requestId);
        if (request.account == address(0)) {
            revert Errors.WithdrawRequestNotExists();
        }
        AssetsProcess.cancelWithdraw(requestId, request, reasonCode);
    }

    function batchUpdateAccountToken(AssetsProcess.UpdateAccountTokenParams calldata params) external override {
        AddressUtils.validEmpty(params.account);
        AssetsProcess.updateAccountToken(params);
    }

    function getAccountInfo(address account) external view override returns (AccountInfo memory) {
        Account.Props storage accountInfo = Account.load(account);
        AccountInfo memory result;
        if (!accountInfo.isExists()) {
            return result;
        }
        address[] memory tokens = accountInfo.getTokens();
        Account.TokenBalance[] memory tokenBalances = new Account.TokenBalance[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            tokenBalances[i] = accountInfo.getTokenBalance(tokens[i]);
        }
        bytes32[] memory positions = accountInfo.getAllPosition();
        result = AccountInfo(account, tokenBalances, tokens, positions, 0, 0, 0, accountInfo.orderHoldInUsd, 0, 0, 0);
        return result;
    }

    function getAccountInfoWithOracles(
        address account,
        OracleProcess.OracleParam[] calldata oracles
    ) external view returns (AccountInfo memory) {
        Account.Props storage accountInfo = Account.load(account);
        AccountInfo memory result;
        if (!accountInfo.isExists()) {
            return result;
        }
        address[] memory tokens = accountInfo.getTokens();
        Account.TokenBalance[] memory tokenBalances = new Account.TokenBalance[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            tokenBalances[i] = accountInfo.getTokenBalance(tokens[i]);
        }
        (int256 accountMMR, int256 crossNetValue, uint256 totalMM) = accountInfo.getCrossMMR(oracles);
        int256 availableValue = accountInfo.getCrossAvailableValue(oracles);
        result = AccountInfo(
            account,
            tokenBalances,
            tokens,
            accountInfo.getAllPosition(),
            accountInfo.getPortfolioNetValue(oracles),
            accountInfo.getTotalUsedValue(oracles),
            availableValue,
            accountInfo.orderHoldInUsd,
            accountMMR,
            crossNetValue,
            totalMM
        );
        return result;
    }

    receive() external payable {}
}
