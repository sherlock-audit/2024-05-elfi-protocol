import _ from 'lodash'

import { extendEnvironment } from 'hardhat/config'

import tokensConfig from './tokens'
import marketsConfig from './markets'
import poolConfig from './usdpool'
import commonConfig from './common'
import rolesConfig from './roles'
import vaultsConfig from './vaults'
import { HardhatRuntimeEnvironment } from 'hardhat/types'

extendEnvironment(async (hre: HardhatRuntimeEnvironment) => {
  hre.elfi = {
    getTokens: _.memoize(async () => tokensConfig(hre)),
    getVaults: _.memoize(async () => vaultsConfig(hre)),
    getMarkets: _.memoize(async () => marketsConfig(hre)),
    getUsdPool: _.memoize(async () => poolConfig(hre)),
    getConfig: _.memoize(async () => commonConfig(hre)),
    getRoles: _.memoize(async () => rolesConfig(hre)),
  }
})
