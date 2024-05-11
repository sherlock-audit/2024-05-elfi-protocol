import { HardhatRuntimeEnvironment } from 'hardhat/types'

export type VaultConfig = {
  address?: string
  deploy?: boolean
}

export type VaultsConfig = { [vault: string]: VaultConfig }

const vaults: {
  [network: string]: VaultsConfig
} = {
  sepolia: {
    TradeVault: {
      address: '',
      deploy: false,
    },
    LpVault: {
      address: '',
      deploy: false,
    },
    PortfolioVault: {
      address: '',
      deploy: false,
    },
  },
  hardhat: {
    TradeVault: {
      address: '',
      deploy: true,
    },
    LpVault: {
      address: '',
      deploy: true,
    },
    PortfolioVault: {
      address: '',
      deploy: true,
    },
  },
  dev: {
    TradeVault: {
      address: '0x5d2794535c726d65f04244fCF5893FFB0B70a0D2',
      deploy: false,
    },
    LpVault: {
      address: '0x601d086ee8F66192523F6D47dA9E453daA75Bb9e',
      deploy: false,
    },
    PortfolioVault: {
      address: '0x54f569A3D4e9B68EA1fd9A226954093AC76B2475',
      deploy: true,
    },
  },
  localhost: {
    TradeVault: {
      address: '',
      deploy: true,
    },
    LpVault: {
      address: '',
      deploy: true,
    },
    PortfolioVault: {
      address: '',
      deploy: true,
    },
  },
}

export default async function (hre: HardhatRuntimeEnvironment): Promise<VaultsConfig> {
  return vaults[hre.network.name]
}
