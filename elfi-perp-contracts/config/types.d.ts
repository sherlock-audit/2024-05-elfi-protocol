import { TokensConfig } from './tokens'
import { VaultsConfig } from './vaults'
import { MarketConfig } from './markets'
import { PoolConfig } from './usdpool'
import { RolesConfig } from './roles'
import getConfig from './common'

declare module 'hardhat/types/runtime' {
  interface HardhatRuntimeEnvironment {
    elfi: {
      getTokens: () => Promise<TokensConfig>
      getVaults: () => Promise<VaultsConfig>
      getMarkets: () => Promise<MarketConfig[]>
      getUsdPool: () => Promise<PoolConfig[]>
      getConfig: () => ReturnType<typeof getConfig>
      getRoles: () => Promise<RolesConfig>
    }
  }
}
