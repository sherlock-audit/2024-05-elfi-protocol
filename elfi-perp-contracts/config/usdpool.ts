import { BigNumberish } from 'ethers'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

import { precision } from '../utils/precision'

export type PoolConfig = {
  name: string
  decimals: BigNumberish
  supportStableTokens: string[]
  stableTokensBorrowingInterestRate: BigNumberish[]
  stableTokensRatioLimit: BigNumberish[]
  poolLiquidityLimit: BigNumberish
  mintFeeRate: BigNumberish
  redeemFeeRate: BigNumberish
  unsettledRatioLimit: BigNumberish
}

const poolConfig: PoolConfig = {
  name: 'xUSD',
  decimals: 6,
  supportStableTokens: ['USDC'],
  stableTokensBorrowingInterestRate: [625000000],
  stableTokensRatioLimit:[0],
  poolLiquidityLimit: precision.pow(8, 4),
  mintFeeRate: 10,
  redeemFeeRate: 10,
  unsettledRatioLimit: 0
}

const config: {
  [network: string]: PoolConfig
} = {
  sepolia: {
    ...poolConfig,
  },
  dev: {
    ...poolConfig,
  },
  hardhat: {
    ...poolConfig,
  },
  localhost: {
    ...poolConfig,
  },
}

export default async function (hre: HardhatRuntimeEnvironment) {
  return config[hre.network.name]
}
