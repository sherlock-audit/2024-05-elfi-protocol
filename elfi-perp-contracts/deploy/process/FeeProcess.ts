import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'FeeProcess',
  libraryNames: [
    'MarketProcess',
    'MarketQueryProcess',
    'OracleProcess',
    'VaultProcess',
    'FeeRewards',
    'AppPoolConfig',
    'AppTradeConfig',
    'TokenUtils',
    'CalUtils',
  ],
}

export default createDeployFunction(options)
