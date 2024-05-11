import { BigNumberish } from 'ethers'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import { precision } from '../utils/precision'

export type MarketConfig = {
  symbol: {
    code: string
    stakeTokenName: string
    indexToken: string
    baseToken: string
    baseTokenName: string
  }
  symbolConfig: {
    maxLeverage: BigNumberish
    tickSize: BigNumberish
    openFeeRate: BigNumberish
    closeFeeRate: BigNumberish
    maxLongOpenInterestCap: BigNumberish
    maxShortOpenInterestCap: BigNumberish
    longShortRatioLimit: BigNumberish
    longShortOiBottomLimit: BigNumberish
  }
  poolConfig: {
    poolLiquidityLimit: BigNumberish
    borrowingBaseInterestRate: BigNumberish
    mintFeeRate: BigNumberish
    redeemFeeRate: BigNumberish
    poolPnlRatioLimit: BigNumberish
    collateralStakingRatioLimit: BigNumberish
    unsettledBaseTokenRatioLimit: BigNumberish
    unsettledStableTokenRatioLimit: BigNumberish
    poolStableTokenRatioLimit: BigNumberish
    poolStableTokenLossLimit: BigNumberish
    assetTokens: string[]
    collateralTokens: string[]
    collateralConfig: {}
  }
}

const commonMarketConfig: MarketConfig = {
  symbol: {
    code: '',
    stakeTokenName: '',
    indexToken: '',
    baseToken: '',
    baseTokenName: '',
  },
  symbolConfig: {
    maxLeverage: precision.rate(20),
    tickSize: precision.price(1),
    openFeeRate: 10,
    closeFeeRate: 10,
    maxLongOpenInterestCap: precision.usd(10_000_000),
    maxShortOpenInterestCap: precision.usd(10_000_000),
    longShortRatioLimit: precision.rate(5, 4),
    longShortOiBottomLimit: precision.usd(100_000),
  },
  poolConfig: {
    poolLiquidityLimit: precision.pow(8, 4),
    borrowingBaseInterestRate: 5000000000,
    mintFeeRate: 10,
    redeemFeeRate: 10,
    poolPnlRatioLimit: 0,
    collateralStakingRatioLimit: 0,
    unsettledBaseTokenRatioLimit: 0,
    unsettledStableTokenRatioLimit: 0,
    poolStableTokenRatioLimit: 0,
    poolStableTokenLossLimit: 0,
    assetTokens: [],
    collateralTokens: [],
    collateralConfig: {},
  },
}

const config: {
  [network: string]: MarketConfig[]
} = {
  sepolia: [
    {
      ...commonMarketConfig,
      symbol: {
        code: 'ETHUSD',
        stakeTokenName: 'xETH',
        indexToken: 'WETH',
        baseToken: 'WETH',
        baseTokenName: 'ETH',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 100,
        closeFeeRate: 100,
        maxLongOpenInterestCap: precision.usd(100_000_000),
        maxShortOpenInterestCap: precision.usd(100_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(10_000_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 10,
        redeemFeeRate: 10,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['WETH'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
    {
      ...commonMarketConfig,
      symbol: {
        code: 'BTCUSD',
        stakeTokenName: 'xBTC',
        indexToken: 'WBTC',
        baseToken: 'WBTC',
        baseTokenName: 'BTC',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 10,
        closeFeeRate: 10,
        maxLongOpenInterestCap: precision.usd(100_000_000),
        maxShortOpenInterestCap: precision.usd(100_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(10_000_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 10,
        redeemFeeRate: 10,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['WBTC'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
    {
      ...commonMarketConfig,
      symbol: {
        code: 'SOLUSD',
        stakeTokenName: 'xSOL',
        indexToken: 'SOL',
        baseToken: 'SOL',
        baseTokenName: 'SOL',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 10,
        closeFeeRate: 10,
        maxLongOpenInterestCap: precision.usd(100_000_000),
        maxShortOpenInterestCap: precision.usd(100_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(10_000_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 10,
        redeemFeeRate: 10,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['SOL'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
  ],
  dev: [
    {
      ...commonMarketConfig,
      symbol: {
        code: 'ETHUSD',
        stakeTokenName: 'xETH',
        indexToken: 'WETH',
        baseToken: 'WETH',
        baseTokenName: 'ETH',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 110,
        closeFeeRate: 130,
        maxLongOpenInterestCap: precision.usd(10_000_000),
        maxShortOpenInterestCap: precision.usd(10_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(100_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 120,
        redeemFeeRate: 150,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['WETH'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
    {
      ...commonMarketConfig,
      symbol: {
        code: 'BTCUSD',
        stakeTokenName: 'xBTC',
        indexToken: 'WBTC',
        baseToken: 'WBTC',
        baseTokenName: 'BTC',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 150,
        closeFeeRate: 170,
        maxLongOpenInterestCap: precision.usd(10_000_000),
        maxShortOpenInterestCap: precision.usd(10_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(100_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 120,
        redeemFeeRate: 150,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['WBTC'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
    {
      ...commonMarketConfig,
      symbol: {
        code: 'SOLUSD',
        stakeTokenName: 'xSOL',
        indexToken: 'SOL',
        baseToken: 'SOL',
        baseTokenName: 'SOL',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 110,
        closeFeeRate: 130,
        maxLongOpenInterestCap: precision.usd(10_000_000),
        maxShortOpenInterestCap: precision.usd(10_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(100_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 120,
        redeemFeeRate: 150,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['SOL'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
  ],
  hardhat: [
    {
      ...commonMarketConfig,
      symbol: {
        code: 'ETHUSD',
        stakeTokenName: 'xETH',
        indexToken: 'WETH',
        baseToken: 'WETH',
        baseTokenName: 'ETH',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 110,
        closeFeeRate: 130,
        maxLongOpenInterestCap: precision.usd(10_000_000),
        maxShortOpenInterestCap: precision.usd(10_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(100_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 120,
        redeemFeeRate: 150,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['WETH'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
    {
      ...commonMarketConfig,
      symbol: {
        code: 'BTCUSD',
        stakeTokenName: 'xBTC',
        indexToken: 'WBTC',
        baseToken: 'WBTC',
        baseTokenName: 'BTC',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 150,
        closeFeeRate: 170,
        maxLongOpenInterestCap: precision.usd(10_000_000),
        maxShortOpenInterestCap: precision.usd(10_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(100_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 120,
        redeemFeeRate: 150,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['WBTC'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
    {
      ...commonMarketConfig,
      symbol: {
        code: 'SOLUSD',
        stakeTokenName: 'xSOL',
        indexToken: 'SOL',
        baseToken: 'SOL',
        baseTokenName: 'SOL',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 110,
        closeFeeRate: 130,
        maxLongOpenInterestCap: precision.usd(10_000_000),
        maxShortOpenInterestCap: precision.usd(10_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(100_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 120,
        redeemFeeRate: 150,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['SOL'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
  ],
  localhost: [
    {
      ...commonMarketConfig,
      symbol: {
        code: 'ETHUSD',
        stakeTokenName: 'xETH',
        indexToken: 'WETH',
        baseToken: 'WETH',
        baseTokenName: 'ETH',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 110,
        closeFeeRate: 130,
        maxLongOpenInterestCap: precision.usd(10_000_000),
        maxShortOpenInterestCap: precision.usd(10_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(100_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 120,
        redeemFeeRate: 150,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['WETH'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
    {
      ...commonMarketConfig,
      symbol: {
        code: 'BTCUSD',
        stakeTokenName: 'xBTC',
        indexToken: 'WBTC',
        baseToken: 'WBTC',
        baseTokenName: 'BTC',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 150,
        closeFeeRate: 170,
        maxLongOpenInterestCap: precision.usd(10_000_000),
        maxShortOpenInterestCap: precision.usd(10_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(100_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 120,
        redeemFeeRate: 150,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['WBTC'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
    {
      ...commonMarketConfig,
      symbol: {
        code: 'SOLUSD',
        stakeTokenName: 'xSOL',
        indexToken: 'SOL',
        baseToken: 'SOL',
        baseTokenName: 'SOL',
      },
      symbolConfig: {
        maxLeverage: precision.rate(20),
        tickSize: precision.price(1, 6), //0.01$
        openFeeRate: 110,
        closeFeeRate: 130,
        maxLongOpenInterestCap: precision.usd(10_000_000),
        maxShortOpenInterestCap: precision.usd(10_000_000),
        longShortRatioLimit: precision.rate(5, 4),
        longShortOiBottomLimit: precision.usd(100_000),
      },
      poolConfig: {
        poolLiquidityLimit: precision.pow(8, 4),
        borrowingBaseInterestRate: 6250000000,
        mintFeeRate: 120,
        redeemFeeRate: 150,
        poolPnlRatioLimit: 0,
        collateralStakingRatioLimit: 0,
        unsettledBaseTokenRatioLimit: 0,
        unsettledStableTokenRatioLimit: 0,
        poolStableTokenRatioLimit: 0,
        poolStableTokenLossLimit: 0,
        assetTokens: ['SOL'],
        collateralTokens: [],
        collateralConfig: {},
      },
    },
  ],
}

export default async function (hre: HardhatRuntimeEnvironment) {
  return config[hre.network.name]
}
