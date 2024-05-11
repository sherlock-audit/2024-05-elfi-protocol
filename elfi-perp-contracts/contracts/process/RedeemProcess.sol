// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IVault.sol";
import "../interfaces/IStake.sol";
import "../vault/Vault.sol";
import "../vault/LpVault.sol";
import "../vault/StakeToken.sol";
import "../storage/StakingAccount.sol";
import "./OracleProcess.sol";
import "./GasProcess.sol";
import "./LpPoolProcess.sol";
import "./LpPoolQueryProcess.sol";
import "./FeeRewardsProcess.sol";
import "./AssetsProcess.sol";
import "./MintProcess.sol";
import "./FeeQueryProcess.sol";

library RedeemProcess {
    using LpPool for LpPool.Props;
    using LpPoolProcess for LpPool.Props;
    using LpPoolQueryProcess for LpPool.Props;
    using UsdPool for UsdPool.Props;
    using LpPoolProcess for UsdPool.Props;
    using LpPoolQueryProcess for UsdPool.Props;
    using StakingAccount for StakingAccount.Props;
    using Account for Account.Props;
    using AccountProcess for Account.Props;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;

    bytes32 constant REDEEM_ID_KEY = keccak256("REDEEM_ID_KEY");

    struct ExecuteRedeemCache {
        uint256 poolValue;
        uint256 totalSupply;
        uint8 tokenDecimals;
        uint256 unStakeUsd;
        uint256 redeemTokenAmount;
        uint256 redeemFee;
    }

    event CreateRedeemEvent(uint256 indexed requestId, Redeem.Request data);
    event RedeemSuccessEvent(uint256 indexed requestId, uint256 redeemTokenAmount, Redeem.Request data);
    event CancelRedeemEvent(uint256 indexed requestId, Redeem.Request data, bytes32 reasonCode);

    function createRedeemStakeTokenRequest(
        IStake.RedeemStakeTokenParams memory params,
        address account,
        uint256 unStakeAmount
    ) external {
        uint256 requestId = UuidCreator.nextId(REDEEM_ID_KEY);

        Redeem.Request storage redeemRequest = Redeem.create(requestId);
        redeemRequest.account = account;
        redeemRequest.receiver = params.receiver;
        redeemRequest.stakeToken = params.stakeToken;
        redeemRequest.redeemToken = params.redeemToken;
        redeemRequest.unStakeAmount = unStakeAmount;
        redeemRequest.minRedeemAmount = params.minRedeemAmount;
        redeemRequest.executionFee = params.executionFee;

        emit CreateRedeemEvent(requestId, redeemRequest);
    }

    function executeRedeemStakeToken(uint256 requestId, Redeem.Request memory redeemRequest) external {
        uint256 redeemAmount;
        if (CommonData.getStakeUsdToken() == redeemRequest.stakeToken) {
            redeemAmount = _redeemStakeUsd(redeemRequest);
        } else if (CommonData.isStakeTokenSupport(redeemRequest.stakeToken)) {
            redeemAmount = _redeemStakeToken(redeemRequest);
        } else {
            revert Errors.StakeTokenInvalid(redeemRequest.stakeToken);
        }

        FeeRewardsProcess.updateAccountFeeRewards(redeemRequest.account, redeemRequest.stakeToken);

        Redeem.remove(requestId);

        emit RedeemSuccessEvent(requestId, redeemAmount, redeemRequest);
    }

    function cancelRedeemStakeToken(
        uint256 requestId,
        Redeem.Request memory redeemRequest,
        bytes32 reasonCode
    ) external {
        Redeem.remove(requestId);
        emit CancelRedeemEvent(requestId, redeemRequest, reasonCode);
    }

    function validateAndDepositRedeemExecutionFee(address account, uint256 executionFee) external {
        AppConfig.ChainConfig memory chainConfig = AppConfig.getChainConfig();
        GasProcess.validateExecutionFeeLimit(executionFee, chainConfig.redeemGasFeeLimit);
        require(msg.value == executionFee, "redeem with execution fee error!");
        AssetsProcess.depositToVault(
            AssetsProcess.DepositParams(
                account,
                chainConfig.wrapperToken,
                executionFee,
                AssetsProcess.DepositFrom.MANUAL,
                true
            )
        );
    }

    function _redeemStakeToken(Redeem.Request memory params) internal returns (uint256 redeemTokenAmount) {
        LpPool.Props storage pool = LpPool.load(params.stakeToken);
        if (pool.baseToken != params.redeemToken) {
            revert Errors.RedeemTokenInvalid(params.stakeToken, params.redeemToken);
        }
        redeemTokenAmount = _executeRedeemStakeToken(pool, params, params.redeemToken);
    }

    function _redeemStakeUsd(Redeem.Request memory params) internal returns (uint256 redeemTokenAmount) {
        address stakeUsdToken = params.stakeToken;
        address account = params.account;
        uint256 stakeTokenAmount = StakeToken(stakeUsdToken).balanceOf(account);
        if (stakeTokenAmount < params.unStakeAmount) {
            revert Errors.RedeemWithAmountNotEnough(account, stakeUsdToken);
        }

        UsdPool.Props storage pool = UsdPool.load();
        redeemTokenAmount = _executeRedeemStakeUsd(pool, stakeUsdToken, params);

        StakingAccount.Props storage accountProps = StakingAccount.load(account);
        accountProps.subStakeUsdAmount(params.unStakeAmount);
        pool.subStableToken(params.redeemToken, redeemTokenAmount);
    }

    function _executeRedeemStakeToken(
        LpPool.Props storage pool,
        Redeem.Request memory params,
        address baseToken
    ) internal returns (uint256) {
        ExecuteRedeemCache memory cache;
        cache.poolValue = pool.getPoolValue();
        cache.totalSupply = TokenUtils.totalSupply(pool.stakeToken);
        cache.tokenDecimals = TokenUtils.decimals(baseToken);
        if (cache.poolValue == 0 || cache.totalSupply == 0) {
            revert Errors.RedeemWithAmountNotEnough(params.account, baseToken);
        }

        cache.unStakeUsd = params.unStakeAmount.mul(cache.poolValue).div(cache.totalSupply);
        cache.redeemTokenAmount = CalUtils.usdToToken(
            cache.unStakeUsd,
            cache.tokenDecimals,
            OracleProcess.getLatestUsdUintPrice(baseToken, false)
        );

        if (pool.getPoolAvailableLiquidity() < cache.redeemTokenAmount) {
            revert Errors.RedeemWithAmountNotEnough(params.account, params.redeemToken);
        }

        if (params.minRedeemAmount > 0 && cache.redeemTokenAmount < params.minRedeemAmount) {
            revert Errors.RedeemStakeTokenTooSmall(cache.redeemTokenAmount);
        }

        StakingAccount.Props storage stakingAccountProps = StakingAccount.load(params.account);
        AppPoolConfig.LpPoolConfig memory poolConfig = AppPoolConfig.getLpPoolConfig(pool.stakeToken);
        uint256 redeemFee = FeeQueryProcess.calcMintOrRedeemFee(cache.redeemTokenAmount, poolConfig.redeemFeeRate);
        FeeProcess.chargeMintOrRedeemFee(
            redeemFee,
            params.stakeToken,
            params.redeemToken,
            params.account,
            FeeProcess.FEE_REDEEM,
            false
        );
        VaultProcess.transferOut(
            params.stakeToken,
            params.redeemToken,
            params.receiver,
            cache.redeemTokenAmount - cache.redeemFee
        );
        pool.subPoolAmount(pool.baseToken, cache.redeemTokenAmount);
        StakeToken(params.stakeToken).burn(params.account, params.unStakeAmount);
        stakingAccountProps.subStakeAmount(params.stakeToken, params.unStakeAmount);

        return cache.redeemTokenAmount;
    }

    function _executeRedeemStakeUsd(
        UsdPool.Props storage pool,
        address stakeUsdToken,
        Redeem.Request memory params
    ) internal returns (uint256) {
        address account = params.account;
        uint256 poolValue = pool.getUsdPoolValue();
        uint256 totalSupply = TokenUtils.totalSupply(stakeUsdToken);
        if (poolValue == 0 || totalSupply == 0) {
            revert Errors.RedeemWithAmountNotEnough(account, params.redeemToken);
        }
        uint8 tokenDecimals = TokenUtils.decimals(params.redeemToken);
        uint256 unStakeUsd = params.unStakeAmount.mul(poolValue).div(totalSupply);
        uint256 redeemTokenAmount = CalUtils.usdToToken(
            unStakeUsd,
            tokenDecimals,
            OracleProcess.getLatestUsdUintPrice(params.redeemToken, false)
        );
        if (params.minRedeemAmount > 0 && redeemTokenAmount < params.minRedeemAmount) {
            revert Errors.RedeemStakeTokenTooSmall(redeemTokenAmount);
        }
        if (pool.getMaxWithdraw(params.redeemToken) < redeemTokenAmount) {
            revert Errors.RedeemWithAmountNotEnough(params.account, params.redeemToken);
        }

        uint256 redeemFee = FeeQueryProcess.calcMintOrRedeemFee(
            redeemTokenAmount,
            AppPoolConfig.getUsdPoolConfig().redeemFeeRate
        );
        FeeProcess.chargeMintOrRedeemFee(
            redeemFee,
            params.stakeToken,
            params.redeemToken,
            params.account,
            FeeProcess.FEE_REDEEM,
            false
        );

        StakeToken(params.stakeToken).burn(account, params.unStakeAmount);
        StakeToken(params.stakeToken).transferOut(params.redeemToken, params.receiver, redeemTokenAmount - redeemFee);
        return redeemTokenAmount;
    }
    
}
