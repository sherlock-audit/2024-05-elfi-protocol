// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IFee.sol";
import "./VaultProcess.sol";
import "./LpPoolQueryProcess.sol";
import "./GasProcess.sol";
import "./AssetsProcess.sol";
import "./TidyRewardsProcess.sol";

library FeeRewardsProcess {
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

    function distributeFeeRewards(uint256 interval) external {
        bytes32[] memory symbols = CommonData.getAllSymbols();
        address[] memory stakeTokens = new address[](symbols.length + 1);
        _updateStableTokenRewardsToUsdPool();
        for (uint256 i; i < symbols.length; i++) {
            stakeTokens[i] = Symbol.load(symbols[i]).stakeToken;
            TidyRewardsProcess.tidyUnsettleRewards(FeeRewards.loadMarketTradingRewards(symbols[i]), stakeTokens[i]);
            TidyRewardsProcess.tidyUnsettleRewards(FeeRewards.loadPoolRewards(stakeTokens[i]), stakeTokens[i]);
            _updateBaseTokenRewardsToLpPool(LpPool.load(stakeTokens[i]));
            TidyRewardsProcess.tidyTradingRewards(symbols[i], stakeTokens[i]);
            // TidyRewardsProcess.tidyMintAndRedeemRewards(stakeTokens[i]);
            _updatePoolApr(stakeTokens[i], interval);
        }
        stakeTokens[stakeTokens.length - 1] = CommonData.getStakeUsdToken();
        TidyRewardsProcess.tidyUnsettleRewards(
            FeeRewards.loadPoolRewards(stakeTokens[stakeTokens.length - 1]),
            stakeTokens[stakeTokens.length - 1]
        );
        _updatePoolApr(stakeTokens[stakeTokens.length - 1], interval);

        FeeRewards.CumulativeRewardsPerStakeTokenData[]
            memory cumulativeRewardsPerStakeTokens = new FeeRewards.CumulativeRewardsPerStakeTokenData[](
                stakeTokens.length
            );
        for (uint256 i; i < stakeTokens.length - 1; i++) {
            cumulativeRewardsPerStakeTokens[i] = _distributePoolRewards(stakeTokens[i]);
        }
        cumulativeRewardsPerStakeTokens[stakeTokens.length - 1] = _distributeUsdPoolRewards();
        FeeRewards.emitUpdateFeeRewardsCumulativeEvent(stakeTokens, cumulativeRewardsPerStakeTokens);
    }

    function updateAccountFeeRewards(address account, address stakeToken) public {
        StakingAccount.Props storage stakingAccount = StakingAccount.load(account);
        StakingAccount.FeeRewards storage accountFeeRewards = stakingAccount.getFeeRewards(stakeToken);
        FeeRewards.MarketRewards storage feeProps = FeeRewards.loadPoolRewards(stakeToken);
        if (accountFeeRewards.openRewardsPerStakeToken == feeProps.getCumulativeRewardsPerStakeToken()) {
            return;
        }
        uint256 stakeTokens = IERC20(stakeToken).balanceOf(account);
        if (
            stakeTokens > 0 &&
            feeProps.getCumulativeRewardsPerStakeToken() - accountFeeRewards.openRewardsPerStakeToken >
            feeProps.getPoolRewardsPerStakeTokenDeltaLimit()
        ) {
            accountFeeRewards.realisedRewardsTokenAmount += (
                stakeToken == CommonData.getStakeUsdToken()
                    ? CalUtils.mul(
                        feeProps.getCumulativeRewardsPerStakeToken() - accountFeeRewards.openRewardsPerStakeToken,
                        stakeTokens
                    )
                    : CalUtils.mulSmallRate(
                        feeProps.getCumulativeRewardsPerStakeToken() - accountFeeRewards.openRewardsPerStakeToken,
                        stakeTokens
                    )
            );
        }
        accountFeeRewards.openRewardsPerStakeToken = feeProps.getCumulativeRewardsPerStakeToken();
        stakingAccount.emitFeeRewardsUpdateEvent(stakeToken);
    }

    function _updatePoolApr(address stakeToken, uint256 interval) internal {
        if (stakeToken == CommonData.getStakeUsdToken()) {
            UsdPool.Props storage pool = UsdPool.load();
            uint256 poolValue = pool.getUsdPoolValue();
            if (poolValue == 0) {
                return;
            }
            FeeRewards.MarketRewards storage poolRewards = FeeRewards.loadPoolRewards(stakeToken);
            uint256 feeValue = _getTotalFeeValueInUsd(poolRewards);
            pool.apr = feeValue.mul(24 * 60 * 365 * CalUtils.RATE_PRECISION).div(poolValue).div(interval);
        } else {
            LpPool.Props storage pool = LpPool.load(stakeToken);
            uint256 poolValue = pool.getPoolValue();
            if (poolValue == 0) {
                return;
            }
            FeeRewards.MarketRewards storage poolRewards = FeeRewards.loadPoolRewards(stakeToken);
            uint256 feeValue = CalUtils.tokenToUsd(
                poolRewards.getFeeAmount(pool.baseToken),
                TokenUtils.decimals(pool.baseToken),
                OracleProcess.getLatestUsdUintPrice(pool.baseToken, false)
            );
            pool.apr = feeValue.mul(24 * 60 * 365 * CalUtils.RATE_PRECISION).div(poolValue).div(interval);
        }
    }

    function _distributePoolRewards(
        address stakeToken
    ) internal returns (FeeRewards.CumulativeRewardsPerStakeTokenData memory) {
        FeeRewards.MarketRewards storage poolRewards = FeeRewards.loadPoolRewards(stakeToken);
        LpPool.Props storage pool = LpPool.load(stakeToken);
        uint256 feeAmount = poolRewards.getFeeAmount(pool.baseToken);
        uint256 totalSupply = TokenUtils.totalSupply(stakeToken);
        if (feeAmount == 0 || totalSupply == 0) {
            return
                FeeRewards.CumulativeRewardsPerStakeTokenData(
                    poolRewards.cumulativeRewardsPerStakeToken,
                    feeAmount,
                    totalSupply
                );
        }
        uint256 poolRewardsPerStakeTokenDelta = CalUtils.divSmallRate(feeAmount, totalSupply);
        poolRewards.cumulativeRewardsPerStakeToken += poolRewardsPerStakeTokenDelta;
        poolRewards.setFeeAmountZero(pool.baseToken);
        poolRewards.addLastRewardsPerStakeTokenDelta(
            poolRewardsPerStakeTokenDelta,
            AppPoolConfig.getStakeConfig().poolRewardsIntervalLimit
        );
        return
            FeeRewards.CumulativeRewardsPerStakeTokenData(
                poolRewards.cumulativeRewardsPerStakeToken,
                feeAmount,
                totalSupply
            );
    }

    function _distributeUsdPoolRewards() internal returns (FeeRewards.CumulativeRewardsPerStakeTokenData memory) {
        address stakeToken = CommonData.getStakeUsdToken();
        FeeRewards.MarketRewards storage poolRewards = FeeRewards.loadPoolRewards(stakeToken);
        address[] memory feeTokens = poolRewards.getFeeTokens();
        uint256 totalSupply = TokenUtils.totalSupply(stakeToken);
        if (feeTokens.length == 0 || totalSupply == 0) {
            return
                FeeRewards.CumulativeRewardsPerStakeTokenData(
                    poolRewards.cumulativeRewardsPerStakeToken,
                    0,
                    totalSupply
                );
        }
        uint256 totalValue = _getTotalFeeValueInUsd(poolRewards);
        if (totalValue == 0) {
            return
                FeeRewards.CumulativeRewardsPerStakeTokenData(
                    poolRewards.cumulativeRewardsPerStakeToken,
                    0,
                    totalSupply
                );
        }
        uint256 poolRewardsPerStakeTokenDelta = CalUtils.div(totalValue, totalSupply);
        poolRewards.cumulativeRewardsPerStakeToken += poolRewardsPerStakeTokenDelta;
        poolRewards.addLastRewardsPerStakeTokenDelta(
            poolRewardsPerStakeTokenDelta,
            AppPoolConfig.getStakeConfig().poolRewardsIntervalLimit
        );
        for (uint256 i; i < feeTokens.length; i++) {
            poolRewards.setFeeAmountZero(feeTokens[i]);
        }
        return
            FeeRewards.CumulativeRewardsPerStakeTokenData(
                poolRewards.cumulativeRewardsPerStakeToken,
                totalValue,
                totalSupply
            );
    }

    function _updateLpPoolTradingRewards(
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

    function _updateBaseTokenRewardsToLpPool(LpPool.Props storage lpPoolProps) internal {
        FeeRewards.MarketRewards storage poolRewards = FeeRewards.loadPoolRewards(lpPoolProps.stakeToken);
        uint256 baseTokenUnsettleFeeAmount = poolRewards.getUnsettleFeeAmount(lpPoolProps.baseToken);
        if (baseTokenUnsettleFeeAmount > 0) {
            lpPoolProps.addUnsettleBaseToken(baseTokenUnsettleFeeAmount.toInt256());
        }
        uint256 baseTokenFeeAmount = poolRewards.getFeeAmount(lpPoolProps.baseToken);
        if (baseTokenFeeAmount > 0) {
            lpPoolProps.addBaseToken(baseTokenFeeAmount - baseTokenUnsettleFeeAmount);
        }
        // address[] memory collateralTokens = poolRewards.getCollateralFeeTokens();
        // for (uint256 i; i < collateralTokens.length; i++) {
        //     uint256 collateralFeeAmount = poolRewards.getCollateralFeeAmount(collateralTokens[i]);
        //     if (collateralFeeAmount > 0) {
        //         Config.StakeCollateralConfig memory collateralConfig = lpPoolProps.getStakeCollateralConfig(
        //             collateralTokens[i]
        //         );
        //         uint256 collateralToBaseTokenAmount = CalUtils.mulRate(collateralFeeAmount, collateralConfig.discount);
        //         lpPoolProps.addCollateralBaseToken(
        //             collateralToBaseTokenAmount,
        //             collateralTokens[i],
        //             collateralFeeAmount
        //         );
        //     }
        // }
    }

    function _updateStableTokenRewardsToUsdPool() internal {
        UsdPool.Props storage usdPool = UsdPool.load();
        FeeRewards.MarketRewards storage poolRewards = FeeRewards.loadPoolRewards(CommonData.getStakeUsdToken());
        address[] memory stableTokens = usdPool.getStableTokens();
        for (uint256 i; i < stableTokens.length; i++) {
            uint256 unsettleFeeAmount = poolRewards.getUnsettleFeeAmount(stableTokens[i]);
            if (unsettleFeeAmount > 0) {
                usdPool.addUnsettleStableToken(stableTokens[i], unsettleFeeAmount);
            }
            uint256 feeAmount = poolRewards.getFeeAmount(stableTokens[i]);
            if (feeAmount > 0) {
                usdPool.addStableToken(stableTokens[i], feeAmount - unsettleFeeAmount);
            }
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
