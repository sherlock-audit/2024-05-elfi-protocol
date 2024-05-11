import { HardhatRuntimeEnvironment } from 'hardhat/types'

export type TokenConfig = {
  address?: string
  decimals: number
  name?: string
  wrapper?: boolean
  intro?: string
  deploy?: boolean
}

export type TokensConfig = { [tokenSymbol: string]: TokenConfig }

const config: {
  [network: string]: TokensConfig
} = {
  sepolia: {
    WETH: {
      decimals: 18,
      address: '0xD8655Bb3479DD49e5d02618Ab84B60Ca678DaC64',
      wrapper: true,
      deploy: false,
    },
    WBTC: {
      decimals: 18,
      address: '0xC4E37E2438DDe0F2983aC0F4692c335d32Ddfa45',
      name: 'BTC',
      intro: 'Bitcoin(WBTC)',
      deploy: false,
    },
    SOL: {
      decimals: 9,
      address: '0xA7Be532b2919218dF172DeFE6B7d8935ec8BbBFF',
      deploy: false,
    },
    USDC: {
      decimals: 6,
      address: '0x6d68e4f6ad26C8cFCC30A66c6A3DB7517E30Be78',
      deploy: false,
    },
  },
  dev: {
    WETH: {
      decimals: 18,
      address: '0x8e4763E76c106C699903796818AA786d687f9fA3',
      wrapper: true,
      deploy: false,
    },
    WBTC: {
      decimals: 18,
      address: '0x55c265bbf6e9D18b4D337482c4943cc3821176a5',
      name: 'BTC',
      intro: 'Bitcoin(WBTC)',
      deploy: false,
    },
    SOL: {
      decimals: 9,
      address: '0x0A812eEc03157D5d304e81162B88995Ef8db8cc2',
      deploy: false,
    },
    USDC: {
      decimals: 6,
      address: '0x5C0823e850BDFFEf29dB79f71e15b14BDB1836E5',
      deploy: false,
    },
  },
  hardhat: {
    WETH: {
      decimals: 18,
      wrapper: true,
      deploy: false,
    },
    WBTC: {
      decimals: 18,
      name: 'BTC',
      intro: 'Bitcoin(WBTC)',
      deploy: true,
    },
    SOL: {
      decimals: 9,
      deploy: true,
    },
    USDC: {
      decimals: 6,
      deploy: true,
    },
  },
  localhost: {
    WETH: {
      decimals: 18,
      deploy: false,
    },
    WBTC: {
      decimals: 18,
      name: 'BTC',
      intro: 'Bitcoin(WBTC)',
      deploy: true,
    },
    SOL: {
      decimals: 9,
      deploy: true,
    },
    USDC: {
      decimals: 6,
      deploy: true,
    },
  },
}

export default async function (hre: HardhatRuntimeEnvironment): Promise<TokensConfig> {
  return config[hre.network.name]
}
