import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { precision } from '../utils/precision'

export default async function ({ network }: HardhatRuntimeEnvironment) {
  if (['hardhat', 'localhost', 'dev', 'sepolia'].includes(network.name)) {
    return {
      commonConfig: {
        uniswapRouter: '0x601d086ee8F66192523F6D47dA9E453daA75Bb9e',
      },
      chainConfig: {
        wrapperToken: 'WETH',
        mintGasFeeLimit: 1_500_000,
        redeemGasFeeLimit: 1_500_000,
        placeIncreaseOrderGasFeeLimit: 1_500_000,
        placeDecreaseOrderGasFeeLimit: 1_500_000,
        positionUpdateMarginGasFeeLimit: 1_500_000,
        positionUpdateLeverageGasFeeLimit: 1_500_000,
        withdrawGasFeeLimit: 1_500_000,
        claimRewardsGasFeeLimit: 1_500_000,
      },
      stakeConfig: {
        collateralProtectFactor: precision.pow(5, 2),
        collateralFactor: precision.pow(5, 3),
        minPrecisionMultiple: 11,
        mintFeeStakingRewardsRatio: precision.pow(27, 3),
        mintFeePoolRewardsRatio: precision.pow(63, 3),
        redeemFeeStakingRewardsRatio: precision.pow(27, 3),
        redeemFeePoolRewardsRatio: precision.pow(63, 3),
        poolRewardsIntervalLimit: 0,
        minApr: precision.pow(2, 4),
        maxApr: precision.pow(20, 5),
      },
      tradeConfig: {
        tokens: ['WBTC', 'WETH', 'SOL', 'USDC'],
        tokenConfigs: {
          WBTC: {
            isSupportCollateral: true,
            priorityCollaterals: [],
            precision: 6,
            discount: precision.pow(99, 3),
            collateralUserCap: precision.token(10),
            collateralTotalCap: precision.token(10_000),
            liabilityUserCap: precision.token(1, 17),
            liabilityTotalCap: precision.token(5),
            interestRateFactor: 10,
            liquidationFactor: precision.rate(5, 3),
          },
          WETH: {
            isSupportCollateral: true,
            priorityCollaterals: [],
            precision: 6,
            discount: precision.pow(99, 3),
            collateralUserCap: precision.token(100),
            collateralTotalCap: precision.token(100_000),
            liabilityUserCap: precision.token(1),
            liabilityTotalCap: precision.token(50),
            interestRateFactor: 10,
            liquidationFactor: precision.rate(5, 3),
          },
          SOL: {
            isSupportCollateral: true,
            priorityCollaterals: [],
            precision: 3,
            discount: precision.pow(99, 3),
            collateralUserCap: precision.token(2000),
            collateralTotalCap: precision.token(2_000_000),
            liabilityUserCap: precision.token(20),
            liabilityTotalCap: precision.token(1000),
            interestRateFactor: 10,
            liquidationFactor: precision.rate(5, 3),
          },
          USDC: {
            isSupportCollateral: true,
            priorityCollaterals: [],
            precision: 2,
            discount: precision.pow(99, 3),
            collateralUserCap: precision.token(200000, 6),
            collateralTotalCap: precision.token(200_000_000, 6),
            liabilityUserCap: precision.token(5000, 6),
            liabilityTotalCap: precision.token(1_000_000, 6),
            interestRateFactor: 10,
            liquidationFactor: precision.rate(5, 3),
          },
        },
        minOrderMarginUSD: precision.usd(10), // 10$
        availableCollateralRatio: precision.rate(12, 4),
        crossLtvLimit: precision.rate(12, 4),
        maxMaintenanceMarginRate: precision.pow(1, 3),
        fundingFeeBaseRate: 20000000000,
        maxFundingBaseRate: 200000000000,
        tradingFeeStakingRewardsRatio: precision.pow(27, 3),
        tradingFeePoolRewardsRatio: precision.pow(63, 3),
        tradingFeeUsdPoolRewardsRatio: precision.pow(1, 4),
        borrowingFeeStakingRewardsRatio: precision.pow(27, 3),
        borrowingFeePoolRewardsRatio: precision.pow(63, 3),
        autoReduceProfitFactor: 0,
        autoReduceLiquidityFactor: 0,
        swapSlipperTokenFactor: precision.pow(5, 3),
      },
    }
  }
}