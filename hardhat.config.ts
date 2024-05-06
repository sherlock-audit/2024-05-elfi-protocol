import 'tsconfig-paths/register'
import { resolve } from 'path'
import { HardhatUserConfig } from 'hardhat/config'
import { config as dotenvConfig } from 'dotenv'
import '@nomicfoundation/hardhat-chai-matchers'
import '@nomicfoundation/hardhat-toolbox'
import '@nomicfoundation/hardhat-ethers'
import 'hardhat-deploy'
import 'hardhat-gas-reporter'
import 'hardhat-deploy-ethers'

import '@typechain/hardhat'
import './config'

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || './.env'
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) })

const alchemyApiKey = process.env.ALCHEMY_API_KEY

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  namedAccounts: {
    deployer: 0,
  },

  gasReporter: {
    enabled: false,
  },

  networks: {
    sepolia: {
      url: `https://arb-sepolia.g.alchemy.com/v2/${alchemyApiKey}`,
      accounts: process.env.ACCOUNT_KEY ? [process.env.ACCOUNT_KEY] : [],
      blockGasLimit: 100000000,
    },
    dev: {
      url: `http://127.0.0.1:8545`,
      accounts: process.env.ACCOUNT_KEY ? [process.env.ACCOUNT_KEY] : [],
      chainId: 31337,
    },
    hardhat: {
      saveDeployments: true,
      allowUnlimitedContractSize: false,
      chainId: 31337,
    },
    localhost: {
      saveDeployments: false,
    },
  },

  solidity: {
    compilers: [
      {
        version: '0.8.18',
        settings: {
          viaIR: false,
          optimizer: {
            enabled: true,
            runs: 4_294_967_295,
          },
        },
      },
    ],
  },

  paths: {
    artifacts: './artifacts',
    cache: './cache',
    sources: './contracts',
    tests: './test',
  },

  typechain: {
    outDir: 'types',
    target: 'ethers-v6',
  },

  mocha: {
    timeout: 1000000,
  },
}

export default config
