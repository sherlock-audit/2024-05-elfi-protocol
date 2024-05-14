import { ethers } from 'hardhat'
import { IPool } from 'types'
import { precision } from './precision'

export const pool = {
  getPoolCollateralAmount(poolInfo: IPool.PoolInfoStruct, collateral: string) {
    for (let i in poolInfo.baseTokenBalance.collateralTokens) {
      if (poolInfo.baseTokenBalance.collateralTokens[i] == collateral) {
        return BigInt(poolInfo.baseTokenBalance.collateralAmounts[i])
      }
    }
    return BigInt(0)
  },

  getPoolStableTokenAmount(poolInfo: IPool.PoolInfoStruct, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return BigInt(poolInfo.stableTokenBalances[i].amount)
      }
    }
    return BigInt(0)
  },

  getPoolStableTokenLossAmount(poolInfo: IPool.PoolInfoStruct, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return BigInt(poolInfo.stableTokenBalances[i].lossAmount)
      }
    }
    return BigInt(0)
  },

  getPoolStableTokenUnsettledAmount(poolInfo: IPool.PoolInfoStruct, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return BigInt(poolInfo.stableTokenBalances[i].unsettledAmount)
      }
    }
    return BigInt(0)
  },

  getUsdPoolStableTokenAmount(poolInfo: IPool.UsdPoolInfoStructOutput, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return BigInt(poolInfo.stableTokenBalances[i].amount)
      }
    }
    return BigInt(0)
  },

  getUsdPoolStableTokenHoldAmount(poolInfo: IPool.UsdPoolInfoStructOutput, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return BigInt(poolInfo.stableTokenBalances[i].holdAmount)
      }
    }
    return BigInt(0)
  },

  getUsdPoolStableTokenUnsettledAmount(poolInfo: IPool.UsdPoolInfoStructOutput, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return BigInt(poolInfo.stableTokenBalances[i].unsettledAmount)
      }
    }
    return BigInt(0)
  },

  getUsdPoolMaxWithdraw(poolInfo: IPool.UsdPoolInfoStructOutput, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return BigInt(poolInfo.stableTokenMaxWithdraws[i])
      }
    }
    return BigInt(0)
  },

  getUsdPoolStableTokenBalance(poolInfo: IPool.UsdPoolInfoStructOutput, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return poolInfo.stableTokenBalances[i]
      }
    }
  },

  getUsdPoolBorrowingFee(poolInfo: IPool.UsdPoolInfoStructOutput, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return poolInfo.borrowingFees[i]
      }
    }
  },

  getUsdPoolBorrowingBaseInterest(poolInfo: IPool.UsdPoolInfoStructOutput, stableToken: string) {
    for (let i in poolInfo.stableTokens) {
      if (poolInfo.stableTokens[i] == stableToken) {
        return poolInfo.borrowingFees[i].baseInterestRate
      }
    }
    return BigInt(0)
  },

}
