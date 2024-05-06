import { ethers } from 'hardhat'
import _ from 'lodash'

export const oracles = {
  format(oraclePrices: any) {
    return _.map(oraclePrices, function (prices) {
      return {
        token: prices.token,
        targetToken: prices.targetToken || ethers.ZeroAddress,
        minPrice: prices.minPrice,
        maxPrice: prices.maxPrice,
      }
    })
  },
}
