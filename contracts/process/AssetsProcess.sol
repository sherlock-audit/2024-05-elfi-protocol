// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IVault.sol";
import "../interfaces/IWETH.sol";
import "../storage/UuidCreator.sol";
import "../storage/Withdraw.sol";
import "../storage/CommonData.sol";
import "../utils/TransferUtils.sol";
import "./AccountProcess.sol";
import "./PositionMarginProcess.sol";

/// @title AssetsProcess Library
/// @dev Library to handle asset operations such as deposit and withdraw
library AssetsProcess {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Account for Account.Props;
    using Position for Position.Props;
    using Order for Order.Props;
    using CommonData for CommonData.Props;

    struct UpdateAccountTokenParams {
        address account;
        address[] tokens;
        int256[] changedTokenAmounts;
    }

    bytes32 constant DEPOSIT_ID_KEY = keccak256("DEPOSIT_ID_KEY");
    bytes32 constant WITHDRAW_ID_KEY = keccak256("WITHDRAW_ID_KEY");

    /// @dev Emitted when a withdraw request is created
    /// @param requestId The ID of the withdraw request
    /// @param data The details of the withdraw request
    event CreateWithdrawEvent(uint256 indexed requestId, Withdraw.Request data);

    /// @dev Emitted when a withdraw request is successfully executed
    /// @param requestId The ID of the withdraw request
    /// @param data The details of the withdraw request
    event WithdrawSuccessEvent(uint256 indexed requestId, Withdraw.Request data);

    /// @dev Emitted when a withdraw request is canceled
    /// @param requestId The ID of the withdraw request
    /// @param data The details of the withdraw request
    /// @param reasonCode The reason for cancellation
    event CancelWithdrawEvent(uint256 indexed requestId, Withdraw.Request data, bytes32 reasonCode);

    /// @dev Emitted when a deposit is made
    /// @param data The details of the deposit
    event Deposit(DepositParams data);

    enum DepositFrom {
        MANUAL,
        ORDER,
        MINT,
        MINT_COLLATERAL
    }

    struct DepositParams {
        address account;
        address token;
        uint256 amount;
        DepositFrom from;
        bool isNativeToken;
    }

    struct WithdrawParams {
        address stakeToken;
        address account;
        address token;
        uint256 amount;
    }

    /// @dev Deposits token to the appropriate vault based on the deposit parameters
    /// @param params The parameters for the deposit
    /// @return The address of the token deposited
    function depositToVault(DepositParams calldata params) public returns (address) {
        IVault vault = IVault(address(this));
        address targetAddress;
        if (DepositFrom.MANUAL == params.from || DepositFrom.MINT_COLLATERAL == params.from) {
            targetAddress = vault.getPortfolioVaultAddress();
        } else if (DepositFrom.ORDER == params.from) {
            targetAddress = vault.getTradeVaultAddress();
        } else if (DepositFrom.MINT == params.from) {
            targetAddress = vault.getLpVaultAddress();
        }
        address token = params.token;
        if (params.isNativeToken) {
            address wrapperToken = AppConfig.getChainConfig().wrapperToken;
            require(wrapperToken == params.token, "Deposit with token error!");
            IWETH(wrapperToken).deposit{ value: params.amount }();
            token = wrapperToken;
            TransferUtils.transfer(token, targetAddress, params.amount);
        } else {
            IERC20(token).safeTransferFrom(params.account, targetAddress, params.amount);
        }
        return token;
    }

    /// @dev Handles the deposit process and updates the account's token balance
    /// @param params The parameters for the deposit
    function deposit(DepositParams calldata params) external {
        address token = depositToVault(params);
        Account.Props storage accountProps = Account.loadOrCreate(params.account);
        if (DepositFrom.MANUAL == params.from) {
            AppTradeTokenConfig.TradeTokenConfig memory tradeTokenConfig = AppTradeTokenConfig.getTradeTokenConfig(
                token
            );
            if (!tradeTokenConfig.isSupportCollateral) {
                revert Errors.TokenIsNotSupportCollateral();
            }
            CommonData.Props storage commonData = CommonData.load();
            uint256 collateralAmount = commonData.getTradeTokenCollateral(token);
            if (collateralAmount + params.amount > tradeTokenConfig.collateralTotalCap) {
                revert Errors.CollateralTotalCapOverflow(token, tradeTokenConfig.collateralTotalCap);
            }
            if (accountProps.getTokenAmount(token) > tradeTokenConfig.collateralUserCap) {
                revert Errors.CollateralUserCapOverflow(token, tradeTokenConfig.collateralUserCap);
            }
            commonData.addTradeTokenCollateral(token, params.amount);
        }
        if (accountProps.owner == address(0)) {
            accountProps.owner = params.account;
        }
        accountProps.addToken(token, params.amount, Account.UpdateSource.DEPOSIT);
        if (DepositFrom.MANUAL == params.from) {
            uint256 repayAmount = accountProps.repayLiability(token);
            if (params.amount > repayAmount) {
                uint256 requestId = UuidCreator.nextId(DEPOSIT_ID_KEY);
                PositionMarginProcess.updateAllPositionFromBalanceMargin(
                    requestId,
                    params.account,
                    token,
                    (params.amount - repayAmount).toInt256(),
                    ""
                );
            }
        }

        emit Deposit(params);
    }

    /// @dev Withdraws tokens from the account
    /// @param requestId The ID of the withdraw request
    /// @param params The parameters for the withdraw
    function withdraw(uint256 requestId, WithdrawParams memory params) public {
        if (params.amount == 0) {
            revert Errors.AmountZeroNotAllowed();
        }
        if (!AppTradeTokenConfig.getTradeTokenConfig(params.token).isSupportCollateral) {
            revert Errors.OnlyCollateralSupported();
        }
        Account.Props storage accountProps = Account.load(params.account);

        if (accountProps.getTokenAmount(params.token) < params.amount) {
            revert Errors.WithdrawWithNoEnoughAmount();
        }
        uint256 tokenPrice = OracleProcess.getLatestUsdUintPrice(params.token, false);
        int256 amountInUsd = CalUtils
            .tokenToUsd(params.amount, TokenUtils.decimals(params.token), tokenPrice)
            .toInt256();
        if (_hasCrossUsed(accountProps) && AccountProcess.getCrossAvailableValue(accountProps) < amountInUsd) {
            revert Errors.WithdrawWithNoEnoughAmount();
        }
        accountProps.subTokenIgnoreUsedAmount(params.token, params.amount, Account.UpdateSource.WITHDRAW);
        VaultProcess.transferOut(
            IVault(address(this)).getPortfolioVaultAddress(),
            params.token,
            params.account,
            params.amount
        );
        PositionMarginProcess.updateAllPositionFromBalanceMargin(
            requestId,
            params.account,
            params.token,
            -(params.amount.toInt256()),
            ""
        );
    }

    /// @dev Creates a withdraw request
    /// @param token The token to withdraw
    /// @param amount The amount to withdraw
    function createWithdrawRequest(address token, uint256 amount) external {
        uint256 requestId = UuidCreator.nextId(WITHDRAW_ID_KEY);
        Withdraw.Request storage request = Withdraw.create(requestId);
        request.account = msg.sender;
        request.token = token;
        request.amount = amount;

        emit CreateWithdrawEvent(requestId, request);
    }

    /// @dev Executes a withdraw request in Second-phase
    /// @param requestId The ID of the withdraw request
    /// @param request The details of the withdraw request
    function executeWithdraw(uint256 requestId, Withdraw.Request memory request) external {
        withdraw(requestId, WithdrawParams(address(0), request.account, request.token, request.amount));
        Withdraw.remove(requestId);

        emit WithdrawSuccessEvent(requestId, request);
    }

    /// @dev Cancels a withdraw request in Second-phase
    /// @param requestId The ID of the withdraw request
    /// @param request The details of the withdraw request
    /// @param reasonCode The reason for cancellation
    function cancelWithdraw(uint256 requestId, Withdraw.Request memory request, bytes32 reasonCode) external {
        Withdraw.remove(requestId);
        emit CancelWithdrawEvent(requestId, request, reasonCode);
    }

    /// @dev Updates the token balances of an account
    /// @param params The parameters for updating the account's token balances
    function updateAccountToken(UpdateAccountTokenParams calldata params) external {
        Account.Props storage accountProps = Account.load(params.account);
        accountProps.checkExists();
        for (uint256 i; i < params.tokens.length; i++) {
            if (params.changedTokenAmounts[i] == 0) {
                continue;
            }
            if (params.changedTokenAmounts[i] > 0) {
                accountProps.addToken(params.tokens[i], params.changedTokenAmounts[i].toUint256());
                accountProps.repayLiability(params.tokens[i]);
            } else {
                accountProps.subToken(params.tokens[i], (-params.changedTokenAmounts[i]).toUint256());
            }
        }
    }

    /// @dev Checks if the account has cross-used tokens
    /// @param account The account to check
    /// @return True if the account has cross-used tokens, false otherwise
    function _hasCrossUsed(Account.Props storage account) internal view returns (bool) {
        if (account.hasLiability()) {
            return true;
        }
        uint256[] memory orders = account.getOrders();
        Order.Props storage orderProps = Order.load();
        for (uint256 i; i < orders.length; i++) {
            if (orderProps.get(orders[i]).isCrossMargin) {
                return true;
            }
        }
        bytes32[] memory positionKeys = account.getAllPosition();
        for (uint256 i; i < positionKeys.length; i++) {
            Position.Props storage position = Position.load(positionKeys[i]);
            if (position.isCrossMargin) {
                return true;
            }
        }
        return false;
    }
}
