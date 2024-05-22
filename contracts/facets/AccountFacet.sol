// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IAccount.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IWETH.sol";
import "../process/AssetsProcess.sol";
import "../process/AccountProcess.sol";
import "../storage/RoleAccessControl.sol";

/// @title Account Facet Contract
/// @dev This contract handles account-related functions such as deposits and withdrawals.
contract AccountFacet is IAccount {
    using SafeERC20 for IERC20;
    using Account for Account.Props;
    using AccountProcess for Account.Props;

    /// @dev Deposit token to account for cross mode trading
    /// @param token Address of the token, e.g., address of USDC
    /// @param amount Token amount to deposit
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

    /// @dev Create a request for token withdrawal
    /// @param token Address of the token, e.g. address of USDC
    /// @param amount Token amount to withdraw
    function createWithdrawRequest(address token, uint256 amount) external override {
        AddressUtils.validEmpty(token);
        if (amount == 0) {
            revert Errors.AmountZeroNotAllowed();
        }
        AssetsProcess.createWithdrawRequest(token, amount);
    }

    /// @dev Execute the given withdraw request, only callable by keeper
    /// @param requestId Unique withdraw request Id
    /// @param oracles Price oracles info from keeper
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

    /// @dev Cancel the given withdraw request, only callable by keeper
    /// @param requestId Unique withdraw request Id
    /// @param reasonCode Cancel reason for event emit
    function cancelWithdraw(uint256 requestId, bytes32 reasonCode) external override {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        Withdraw.Request memory request = Withdraw.get(requestId);
        if (request.account == address(0)) {
            revert Errors.WithdrawRequestNotExists();
        }
        AssetsProcess.cancelWithdraw(requestId, request, reasonCode);
    }

    /// @dev Batch update account token
    /// @param params Parameters for updating account token
    function batchUpdateAccountToken(AssetsProcess.UpdateAccountTokenParams calldata params) external override {
        AddressUtils.validEmpty(params.account);
        AssetsProcess.updateAccountToken(params);
    }

    /// @dev Get account information for cross mode trading
    /// @param account Address of the account
    /// @return AccountInfo structure containing account details
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

    /// @dev Get account information with oracles for cross trading mode
    /// @param account Address of the account
    /// @param oracles Oracle parameters, we can get availableValue, accountMMR, crossNetValue... with oracles data
    /// @return AccountInfo structure containing account details
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

    /// @dev Fallback function to receive Ether
    receive() external payable {}
}
