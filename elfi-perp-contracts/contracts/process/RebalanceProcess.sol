// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "../interfaces/IRebalance.sol";
import "../interfaces/IVault.sol";
import "../interfaces/ISwap.sol";
import "../storage/LpPool.sol";
import "../storage/UsdPool.sol";
import "../storage/CommonData.sol";
import "../storage/AppTradeConfig.sol";
import "../utils/TokenUtils.sol";
import "../utils/CalUtils.sol";
import "./VaultProcess.sol";
import "./OracleProcess.sol";
import "./SwapProcess.sol";

library RebalanceProcess {
    using LpPool for LpPool.Props;
    using UsdPool for UsdPool.Props;
    using CommonData for CommonData.Props;
    using SafeCast for uint256;
    using SafeCast for int256;

    struct RebalanceUnsettleCache {
        int256[] poolUnsettledAmount;
        int256 totalUnsettledAmount;
        uint256[] settledAmount;
        int256 tokenLiability;
        uint256 reduceTransferAmount;
    }

    function autoRebalance() external {
        address[] memory stakeTokens = CommonData.getAllStakeTokens();
        for (uint256 i; i < stakeTokens.length; i++) {
            LpPool.Props storage pool = LpPool.load(stakeTokens[i]);
            _rebalanceUnsettle(pool.baseToken, false, stakeTokens);
        }
        address[] memory stableTokens = UsdPool.getSupportedStableTokens();
        for (uint256 i; i < stableTokens.length; i++) {
            _rebalanceUnsettle(stableTokens[i], true, stakeTokens);
        }
        for (uint256 i; i < stakeTokens.length; i++) {
            _rebalanceStableTokens(stakeTokens[i]);
        }
    }

    function _rebalanceStableTokens(address stakeToken) internal {
        LpPool.Props storage pool = LpPool.load(stakeToken);
        address[] memory tokens = pool.getStableTokens();
        int256[] memory netStableTokenAmount = new int256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            LpPool.TokenBalance storage tokenBalance = pool.getStableTokenBalance(tokens[i]);
            netStableTokenAmount[i] = tokenBalance.amount >= tokenBalance.lossAmount
                ? (tokenBalance.amount - tokenBalance.lossAmount).toInt256()
                : -(tokenBalance.lossAmount - tokenBalance.amount).toInt256();
        }
        for (uint256 i; i < netStableTokenAmount.length; i++) {
            if (netStableTokenAmount[i] == 0) {
                continue;
            }
            if (netStableTokenAmount[i] < 0) {
                uint256 tokenNetStableTokenAmount = (-netStableTokenAmount[i]).toUint256();
                for (uint256 j; j < netStableTokenAmount.length; j++) {
                    if (netStableTokenAmount[j] <= 0) {
                        continue;
                    }
                    uint256 reduceProfitTokenAmount = netStableTokenAmount[j].toUint256();
                    uint256 offsetLossStableTokenAmount = CalUtils.tokenToToken(
                        reduceProfitTokenAmount,
                        TokenUtils.decimals(tokens[j]),
                        TokenUtils.decimals(tokens[i]),
                        OracleProcess.getLatestUsdUintPrice(tokens[j], true),
                        OracleProcess.getLatestUsdUintPrice(tokens[i], false)
                    );

                    if (offsetLossStableTokenAmount > tokenNetStableTokenAmount) {
                        offsetLossStableTokenAmount = tokenNetStableTokenAmount;
                        reduceProfitTokenAmount = CalUtils.tokenToToken(
                            tokenNetStableTokenAmount,
                            TokenUtils.decimals(tokens[i]),
                            TokenUtils.decimals(tokens[j]),
                            OracleProcess.getLatestUsdUintPrice(tokens[i], false),
                            OracleProcess.getLatestUsdUintPrice(tokens[j], true)
                        );
                    }
                    netStableTokenAmount[i] = netStableTokenAmount[i] + offsetLossStableTokenAmount.toInt256();
                    netStableTokenAmount[j] = netStableTokenAmount[j] - reduceProfitTokenAmount.toInt256();
                    if (netStableTokenAmount[i] >= 0) {
                        break;
                    }
                }
            }
        }

        UsdPool.Props storage usdPool = UsdPool.load();
        address stakeUsd = CommonData.getStakeUsdToken();
        for (uint256 i; i < netStableTokenAmount.length; i++) {
            LpPool.TokenBalance storage tokenBalance = pool.getStableTokenBalance(tokens[i]);
            if (netStableTokenAmount[i] == 0) {
                usdPool.settleStableToken(tokens[i], tokenBalance.lossAmount, true);
                usdPool.addStableToken(
                    tokens[i],
                    tokenBalance.amount > tokenBalance.lossAmount ? tokenBalance.amount - tokenBalance.lossAmount : 0
                );
                VaultProcess.transferOut(stakeToken, tokens[i], stakeUsd, tokenBalance.amount);
                tokenBalance.amount = 0;
                tokenBalance.lossAmount = 0;
            } else if (netStableTokenAmount[i] > 0) {
                usdPool.settleStableToken(tokens[i], tokenBalance.lossAmount, true);
                usdPool.addStableToken(
                    tokens[i],
                    tokenBalance.amount - netStableTokenAmount[i].toUint256() > tokenBalance.lossAmount
                        ? tokenBalance.amount - netStableTokenAmount[i].toUint256() - tokenBalance.lossAmount
                        : 0
                );
                VaultProcess.transferOut(
                    stakeToken,
                    tokens[i],
                    stakeUsd,
                    tokenBalance.amount > netStableTokenAmount[i].toUint256()
                        ? tokenBalance.amount - netStableTokenAmount[i].toUint256()
                        : 0
                );
                ISwap.SwapSingleResult memory swapResult = _swapToBaseToken(
                    stakeToken,
                    tokens[i],
                    netStableTokenAmount[i].toUint256(),
                    pool.baseToken
                );
                pool.subStableToken(tokens[i], swapResult.reduceFromAmount);
                pool.addBaseToken(swapResult.toTokenAmount);

                tokenBalance.amount = netStableTokenAmount[i].toUint256() - swapResult.reduceFromAmount;
                tokenBalance.lossAmount = 0;
            } else {
                ISwap.SwapSingleResult memory swapResult = _swapToStableTokens(
                    stakeToken,
                    pool.baseToken,
                    tokens[i],
                    (-netStableTokenAmount[i]).toUint256()
                );
                pool.subBaseToken(swapResult.reduceFromAmount);
                pool.addStableToken(tokens[i], swapResult.toTokenAmount);
                usdPool.settleStableToken(tokens[i], tokenBalance.lossAmount, true);

                VaultProcess.transferOut(
                    stakeToken,
                    tokens[i],
                    stakeUsd,
                    tokenBalance.amount - swapResult.toTokenAmount + (-netStableTokenAmount[i]).toUint256()
                );
                tokenBalance.amount = swapResult.toTokenAmount - (-netStableTokenAmount[i]).toUint256();
                tokenBalance.lossAmount = 0;
            }
        }
    }

    function _swapToBaseToken(
        address stakeToken,
        address fromToken,
        uint256 fromAmount,
        address toToken
    ) internal returns (ISwap.SwapSingleResult memory) {
        uint256 toTokenAmount = CalUtils.tokenToToken(
            fromAmount,
            TokenUtils.decimals(fromToken),
            TokenUtils.decimals(toToken),
            OracleProcess.getLatestUsdUintPrice(fromToken, true),
            OracleProcess.getLatestUsdUintPrice(toToken, false)
        );
        toTokenAmount -= CalUtils.mulRate(toTokenAmount, AppTradeConfig.getTradeConfig().swapSlipperTokenFactor);
        return
            SwapProcess.singleSwap(
                ISwap.SwapSingleParam(stakeToken, fromToken, fromAmount, toTokenAmount, toToken, stakeToken)
            );
    }

    function _swapToStableTokens(
        address stakeToken,
        address fromToken,
        address toToken,
        uint256 toAmount
    ) internal returns (ISwap.SwapSingleResult memory) {
        uint256 needTokenAmount = CalUtils.tokenToToken(
            toAmount,
            TokenUtils.decimals(toToken),
            TokenUtils.decimals(fromToken),
            OracleProcess.getLatestUsdUintPrice(toToken, true),
            OracleProcess.getLatestUsdUintPrice(fromToken, false)
        );
        needTokenAmount += CalUtils.mulRate(
            needTokenAmount,
            AppTradeConfig.getTradeConfig().swapSlipperTokenFactor
        );
        return
            SwapProcess.singleSwap(
                ISwap.SwapSingleParam(stakeToken, fromToken, needTokenAmount, toAmount, toToken, stakeToken)
            );
    }

    function _rebalanceUnsettle(address token, bool isStableToken, address[] memory stakeTokens) internal {
        if (
            (isStableToken && !UsdPool.isSupportStableToken(token)) ||
            (!isStableToken && UsdPool.isSupportStableToken(token))
        ) {
            return;
        }
        RebalanceUnsettleCache memory cache;
        cache.poolUnsettledAmount = new int256[](stakeTokens.length);
        for (uint256 i; i < stakeTokens.length; i++) {
            LpPool.Props storage pool = LpPool.load(stakeTokens[i]);
            if (isStableToken) {
                cache.poolUnsettledAmount[i] = pool.getStableTokenBalance(token).unsettledAmount;
            } else {
                cache.poolUnsettledAmount[i] = token == pool.baseToken
                    ? pool.baseTokenBalance.unsettledAmount
                    : int256(0);
            }

            if (cache.poolUnsettledAmount[i] <= 0) {
                continue;
            }
            cache.totalUnsettledAmount += cache.poolUnsettledAmount[i];
        }
        if (cache.totalUnsettledAmount <= 0) {
            return;
        }
        cache.settledAmount = new uint256[](stakeTokens.length);
        cache.tokenLiability = CommonData.load().getTokenLiability(token).toInt256();
        if (cache.totalUnsettledAmount > cache.tokenLiability) {
            uint256 totalTransferAmount = cache.totalUnsettledAmount.toUint256() - cache.tokenLiability.toUint256();
            cache.reduceTransferAmount = totalTransferAmount;
            address portfolioVaultAddress = IVault(address(this)).getPortfolioVaultAddress();

            for (uint256 i; i < stakeTokens.length; i++) {
                if (cache.poolUnsettledAmount[i] == 0) {
                    continue;
                }
                LpPool.Props storage pool = LpPool.load(stakeTokens[i]);
                if (i == stakeTokens.length - 1) {
                    cache.settledAmount[i] = cache.reduceTransferAmount;
                    cache.reduceTransferAmount = 0;
                } else {
                    cache.settledAmount[i] = CalUtils.mulDiv(
                        totalTransferAmount,
                        cache.poolUnsettledAmount[i].toUint256(),
                        cache.totalUnsettledAmount.toUint256()
                    );
                    cache.reduceTransferAmount -= cache.settledAmount[i];
                }
                if (isStableToken) {
                    pool.settleStableToken(token, cache.settledAmount[i]);
                } else {
                    pool.settleBaseToken(cache.settledAmount[i]);
                }
                VaultProcess.transferOut(portfolioVaultAddress, token, stakeTokens[i], cache.settledAmount[i]);
            }
        }
    }
}
