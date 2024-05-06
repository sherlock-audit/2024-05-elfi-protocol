import { ethers } from 'hardhat'
import { Config, ConfigProcess } from 'types'

export const configs = {
  getTradeTokenConfig(config: ConfigProcess.CommonConfigParamsStruct, token: string) {
    for (let i in config.tradeConfig.tradeTokens) {
      if (config.tradeConfig.tradeTokens[i] == token) {
        return config.tradeConfig.tradeTokenConfigs[i]
      }
    }
  },

  getTradeTokenPrecision(config: ConfigProcess.CommonConfigParamsStruct, token: string) {
    for (let i in config.tradeConfig.tradeTokens) {
      if (config.tradeConfig.tradeTokens[i] == token) {
        return config.tradeConfig.tradeTokenConfigs[i].precision
      }
    }
    return BigInt(0)
  },

  getTradeTokenDiscount(config: ConfigProcess.CommonConfigParamsStruct, token: string) {
    for (let i in config.tradeConfig.tradeTokens) {
      if (config.tradeConfig.tradeTokens[i] == token) {
        return BigInt(config.tradeConfig.tradeTokenConfigs[i].discount)
      }
    }
    return BigInt(0)
  },

  getTradeTokenLiquidationFactor(config: ConfigProcess.CommonConfigParamsStruct, token: string) {
    for (let i in config.tradeConfig.tradeTokens) {
      if (config.tradeConfig.tradeTokens[i] == token) {
        return BigInt(config.tradeConfig.tradeTokenConfigs[i].liquidationFactor)
      }
    }
    return BigInt(0)
  },

}
