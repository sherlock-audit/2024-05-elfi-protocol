// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IStake.sol";
import "../interfaces/IAccount.sol";
import "../process/MintProcess.sol";
import "../process/RedeemProcess.sol";
import "../process/AssetsProcess.sol";
import "../process/GasProcess.sol";
import "../storage/CommonData.sol";
import "../storage/UuidCreator.sol";
import "../storage/RoleAccessControl.sol";

contract StakeFacet is IStake, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using LpPool for LpPool.Props;
    using Account for Account.Props;

    function createMintStakeTokenRequest(MintStakeTokenParams calldata params) external payable override nonReentrant {
        if (params.requestTokenAmount == 0) {
            revert Errors.MintWithAmountZero();
        }
        if (params.stakeToken == address(0)) {
            revert Errors.MintWithParamError();
        }

        address account = msg.sender;
        address token = params.requestToken;
        if (CommonData.getStakeUsdToken() == params.stakeToken) {
            if (!UsdPool.isSupportStableToken(token)) {
                revert Errors.MintTokenInvalid(params.stakeToken, token);
            }
        } else if (CommonData.isStakeTokenSupport(params.stakeToken)) {
            LpPool.Props storage pool = LpPool.load(params.stakeToken);
            if (pool.baseToken != token) {
                revert Errors.MintTokenInvalid(params.stakeToken, token);
            }
        } else {
            revert Errors.StakeTokenInvalid(params.stakeToken);
        }

        if (params.walletRequestTokenAmount > 0) {
            require(!params.isNativeToken || msg.value == params.walletRequestTokenAmount, "Deposit eth amount error!");
            AssetsProcess.depositToVault(
                AssetsProcess.DepositParams(
                    account,
                    params.requestToken,
                    params.walletRequestTokenAmount,
                    params.isCollateral ? AssetsProcess.DepositFrom.MINT_COLLATERAL : AssetsProcess.DepositFrom.MINT,
                    params.isNativeToken
                )
            );
        }

        (uint256 walletRequestTokenAmount, bool isExecutionFeeFromLpVault) = MintProcess
            .validateAndDepositMintExecutionFee(account, params);
        if (params.requestTokenAmount < walletRequestTokenAmount) {
            revert Errors.MintWithParamError();
        }

        MintProcess.createMintStakeTokenRequest(
            params,
            account,
            token,
            walletRequestTokenAmount,
            isExecutionFeeFromLpVault
        );
    }

    function executeMintStakeToken(
        uint256 requestId,
        OracleProcess.OracleParam[] calldata oracles
    ) external override nonReentrant {
        uint256 startGas = gasleft();
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        Mint.Request memory mintRequest = Mint.get(requestId);
        if (mintRequest.account == address(0)) {
            revert Errors.MintRequestNotExists();
        }
        OracleProcess.setOraclePrice(oracles);

        MintProcess.executeMintStakeToken(requestId, mintRequest);

        OracleProcess.clearOraclePrice();

        GasProcess.processExecutionFee(
            GasProcess.PayExecutionFeeParams(
                mintRequest.isExecutionFeeFromLpVault
                    ? IVault(address(this)).getLpVaultAddress()
                    : IVault(address(this)).getPortfolioVaultAddress(),
                mintRequest.executionFee,
                startGas,
                msg.sender,
                mintRequest.account
            )
        );
    }

    function cancelMintStakeToken(uint256 requestId, bytes32 reasonCode) external {
        uint256 startGas = gasleft();
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        Mint.Request memory mintRequest = Mint.get(requestId);
        if (mintRequest.account == address(0)) {
            revert Errors.MintRequestNotExists();
        }

        MintProcess.cancelMintStakeToken(requestId, mintRequest, reasonCode);

        GasProcess.processExecutionFee(
            GasProcess.PayExecutionFeeParams(
                mintRequest.isExecutionFeeFromLpVault
                    ? IVault(address(this)).getLpVaultAddress()
                    : IVault(address(this)).getPortfolioVaultAddress(),
                mintRequest.executionFee,
                startGas,
                msg.sender,
                mintRequest.account
            )
        );
    }

    function createRedeemStakeTokenRequest(
        RedeemStakeTokenParams calldata params
    ) external payable override nonReentrant {
        require(params.unStakeAmount > 0, "unStakeAmount == 0");
        AddressUtils.validEmpty(params.receiver);

        address account = msg.sender;
        uint256 stakeTokenAmount = StakeToken(params.stakeToken).balanceOf(account);
        if (stakeTokenAmount == 0) {
            revert Errors.RedeemWithAmountNotEnough(account, params.stakeToken);
        }
        if (stakeTokenAmount < params.unStakeAmount) {
            revert Errors.RedeemWithAmountNotEnough(account, params.stakeToken);
        }
        if (CommonData.getStakeUsdToken() == params.stakeToken) {
            if (!UsdPool.isSupportStableToken(params.redeemToken)) {
                revert Errors.RedeemTokenInvalid(params.stakeToken, params.redeemToken);
            }
        } else if (CommonData.isStakeTokenSupport(params.stakeToken)) {
            LpPool.Props storage pool = LpPool.load(params.stakeToken);
            if (pool.baseToken != params.redeemToken) {
                revert Errors.RedeemTokenInvalid(params.stakeToken, params.redeemToken);
            }
        } else {
            revert Errors.StakeTokenInvalid(params.stakeToken);
        }

        RedeemProcess.validateAndDepositRedeemExecutionFee(account, params.executionFee);
        RedeemProcess.createRedeemStakeTokenRequest(params, account, params.unStakeAmount);
    }

    function executeRedeemStakeToken(
        uint256 requestId,
        OracleProcess.OracleParam[] calldata oracles
    ) external override nonReentrant {
        uint256 startGas = gasleft();
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        OracleProcess.setOraclePrice(oracles);
        Redeem.Request memory request = Redeem.get(requestId);
        if (request.receiver == address(0)) {
            revert Errors.RedeemRequestNotExists();
        }
        RedeemProcess.executeRedeemStakeToken(requestId, request);

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

    function cancelRedeemStakeToken(uint256 requestId, bytes32 reasonCode) external {
        uint256 startGas = gasleft();
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_KEEPER);
        Redeem.Request memory redeemRequest = Redeem.get(requestId);
        if (redeemRequest.receiver == address(0)) {
            revert Errors.RedeemRequestNotExists();
        }

        RedeemProcess.cancelRedeemStakeToken(requestId, redeemRequest, reasonCode);

        GasProcess.processExecutionFee(
            GasProcess.PayExecutionFeeParams(
                IVault(address(this)).getPortfolioVaultAddress(),
                redeemRequest.executionFee,
                startGas,
                msg.sender,
                redeemRequest.account
            )
        );
    }
}
