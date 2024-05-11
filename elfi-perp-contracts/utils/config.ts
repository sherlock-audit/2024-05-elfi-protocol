import { ethers } from 'hardhat'
import { precision } from './precision'

export const configUtils = {
  // getPoolCollateralConfig(lpPoolConfig: IConfig.LpPoolConfigParamsStructOutput, collateral: string) {
  //   for (let i in lpPoolConfig.supportCollateralTokens) {
  //     if (lpPoolConfig.supportCollateralTokens[i] == collateral) {
  //       return lpPoolConfig.collateralTokensConfigs[i]
  //     }
  //   }
  //   return {
  //     discount: precision.rate(1),
  //     collateralTotalCap: precision.token(1_000_000),
  //   }
  // },

  // getPoolCollateralDiscount(lpPoolConfig: IConfig.LpPoolConfigParamsStructOutput, collateral: string) {
  //   for (let i in lpPoolConfig.supportCollateralTokens) {
  //     if (lpPoolConfig.supportCollateralTokens[i] == collateral) {
  //       return BigInt(lpPoolConfig.collateralTokensConfigs[i].discount)
  //     }
  //   }
  //   return precision.rate(1)
  // },

  getUsdPoolBorrowingBaseInterest(usdPoolConfig:any, stableToken: string) {
    for (let i in usdPoolConfig.supportStableTokens) {
      if (usdPoolConfig.supportStableTokens[i] == stableToken) {
        return usdPoolConfig.stableTokensBorrowingInterestRate[i]
      }
    }
    return BigInt(0)
  }
}
