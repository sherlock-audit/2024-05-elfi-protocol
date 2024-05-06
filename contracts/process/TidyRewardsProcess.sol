// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IFee.sol";
import "../storage/FeeRewards.sol";
import "../storage/StakingAccount.sol";
import "../storage/UuidCreator.sol";
import "./VaultProcess.sol";
import "./LpPoolQueryProcess.sol";
import "./GasProcess.sol";
import "./AssetsProcess.sol";

library TidyRewardsProcess {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using UsdPool for UsdPool.Props;
    using LpPool for LpPool.Props;
    using LpPoolQueryProcess for LpPool.Props;
    using LpPoolQueryProcess for UsdPool.Props;
    using StakingAccount for StakingAccount.Props;
    using FeeRewards for FeeRewards.MarketRewards;
    using FeeRewards for FeeRewards.StakingRewards;

    struct TidyTradingRewardsCache {
        uint256 totalFeeValueInUsd;
        uint256 usdPoolShouldTakeInUsd;
        address maxAmountStableToken;
        uint256 usdTokenNeedAmount;
        uint256 baseTokenSwapAmount;
    }

    function tidyUnsettleRewards(FeeRewards.MarketRewards storage marketRewards, address stakeToken) external {
        address[] memory tokens = marketRewards.getFeeTokens();
        for (uint256 i; i < tokens.length; i++) {
            uint256 unsettleAmount = marketRewards.getUnsettleFeeAmount(tokens[i]);
            if (unsettleAmount == 0) {
                continue;
            }
            uint256 realTransferOut = VaultProcess.tryTransferOut(
                IVault(address(this)).getPortfolioVaultAddress(),
                tokens[i],
                stakeToken,
                unsettleAmount
            );
            if (realTransferOut > 0) {
                marketRewards.subUnsettleFeeAmount(tokens[i], realTransferOut);
            }
        }
    }

    function tidyTradingRewards(bytes32 symbol, address stakeToken) external {
        FeeRewards.MarketRewards storage marketTradingRewardsProps = FeeRewards.loadMarketTradingRewards(symbol);
        TidyTradingRewardsCache memory tidyCache;
        tidyCache.totalFeeValueInUsd = _getTotalFeeValueInUsd(marketTradingRewardsProps);
        if (tidyCache.totalFeeValueInUsd == 0) {
            return;
        }
        tidyCache.usdPoolShouldTakeInUsd = CalUtils.mulRate(
            tidyCache.totalFeeValueInUsd,
            AppTradeConfig.getTradeConfig().tradingFeeUsdPoolRewardsRatio
        );
        UsdPool.Props storage usdPool = UsdPool.load();
        address[] memory stableTokens = usdPool.getStableTokens();
        FeeRewards.MarketRewards storage usdPoolRewards = FeeRewards.loadPoolRewards(CommonData.getStakeUsdToken());
        for (uint256 i; i < stableTokens.length; i++) {
            uint256 transferTokenAmount = marketTradingRewardsProps.getFeeAmount(stableTokens[i]);
            if (transferTokenAmount == 0) {
                continue;
            }
            uint256 usdToken = CalUtils.usdToToken(
                tidyCache.usdPoolShouldTakeInUsd,
                TokenUtils.decimals(stableTokens[i]),
                OracleProcess.getLatestUsdUintPrice(stableTokens[i], true)
            );
            if (transferTokenAmount < usdToken) {
                tidyCache.usdPoolShouldTakeInUsd -= CalUtils.tokenToUsd(
                    transferTokenAmount,
                    TokenUtils.decimals(stableTokens[i]),
                    OracleProcess.getLatestUsdUintPrice(stableTokens[i], true)
                );
            } else {
                transferTokenAmount = usdToken;
                tidyCache.usdPoolShouldTakeInUsd = 0;
            }
            usdPool.addStableToken(stableTokens[i], transferTokenAmount);
            usdPoolRewards.addFeeAmount(stableTokens[i], transferTokenAmount);
            marketTradingRewardsProps.subFeeAmount(stableTokens[i], transferTokenAmount);

            if (tidyCache.usdPoolShouldTakeInUsd == 0) {
                break;
            }
        }
        LpPool.Props storage lpPoolProps = LpPool.load(stakeToken);
        if (tidyCache.usdPoolShouldTakeInUsd > 0) {
            tidyCache.maxAmountStableToken = usdPool.getMaxAmountStableToken();
            tidyCache.usdTokenNeedAmount = CalUtils.usdToToken(
                tidyCache.usdPoolShouldTakeInUsd,
                TokenUtils.decimals(tidyCache.maxAmountStableToken),
                OracleProcess.getLatestUsdUintPrice(tidyCache.maxAmountStableToken, false)
            );
            tidyCache.baseTokenSwapAmount = CalUtils.usdToToken(
                tidyCache.usdPoolShouldTakeInUsd,
                TokenUtils.decimals(lpPoolProps.baseToken),
                OracleProcess.getLatestUsdUintPrice(lpPoolProps.baseToken, true)
            );
            tidyCache.baseTokenSwapAmount += CalUtils.mulRate(
                tidyCache.baseTokenSwapAmount,
                AppTradeConfig.getTradeConfig().swapSlipperTokenFactor
            );
            usdPool.addUnsettleStableToken(tidyCache.maxAmountStableToken, tidyCache.usdTokenNeedAmount);
            lpPoolProps.addLossStableToken(tidyCache.maxAmountStableToken, tidyCache.usdTokenNeedAmount);
            lpPoolProps.addBaseToken(tidyCache.baseTokenSwapAmount);
            marketTradingRewardsProps.subFeeAmount(lpPoolProps.baseToken, tidyCache.baseTokenSwapAmount);
            usdPoolRewards.addFeeAmount(tidyCache.maxAmountStableToken, tidyCache.usdTokenNeedAmount);
        }
        updateLpPoolTradingRewards(marketTradingRewardsProps, lpPoolProps, stableTokens);
    }

    function updateLpPoolTradingRewards(
        FeeRewards.MarketRewards storage marketTradingRewardsProps,
        LpPool.Props storage lpPoolProps,
        address[] memory stableTokens
    ) internal {
        FeeRewards.MarketRewards storage poolRewards = FeeRewards.loadPoolRewards(lpPoolProps.stakeToken);
        uint256 feeAmount = marketTradingRewardsProps.getFeeAmount(lpPoolProps.baseToken);
        if (feeAmount > 0) {
            lpPoolProps.addBaseToken(feeAmount);
            poolRewards.addFeeAmount(lpPoolProps.baseToken, feeAmount);
            marketTradingRewardsProps.subFeeAmount(lpPoolProps.baseToken, feeAmount);
        }
        uint8 baseTokenDecimals = TokenUtils.decimals(lpPoolProps.baseToken);
        uint256 baseTokenPrice = OracleProcess.getLatestUsdUintPrice(lpPoolProps.baseToken, false);
        for (uint256 i; i < stableTokens.length; i++) {
            feeAmount = marketTradingRewardsProps.getFeeAmount(stableTokens[i]);
            if (feeAmount == 0) {
                continue;
            }
            uint256 toBaseTokenAmount = CalUtils.tokenToToken(
                feeAmount,
                TokenUtils.decimals(stableTokens[i]),
                baseTokenDecimals,
                OracleProcess.getLatestUsdUintPrice(stableTokens[i], true),
                baseTokenPrice
            );
            toBaseTokenAmount -= CalUtils.mulRate(
                toBaseTokenAmount,
                AppTradeConfig.getTradeConfig().swapSlipperTokenFactor
            );
            lpPoolProps.addStableToken(stableTokens[i], feeAmount);
            marketTradingRewardsProps.setFeeAmountZero(stableTokens[i]);
            poolRewards.addFeeAmount(lpPoolProps.baseToken, toBaseTokenAmount);
        }
    }

    function _getTotalFeeValueInUsd(FeeRewards.MarketRewards storage feeProps) internal view returns (uint256) {
        uint256 totalFeeValue;
        address[] memory allTokens = feeProps.getFeeTokens();
        for (uint256 i; i < allTokens.length; i++) {
            uint256 tokenValue = CalUtils.tokenToUsd(
                feeProps.getFeeAmount(allTokens[i]),
                TokenUtils.decimals(allTokens[i]),
                OracleProcess.getLatestUsdUintPrice(allTokens[i], true)
            );
            totalFeeValue += tokenValue;
        }
        return totalFeeValue;
    }
}
