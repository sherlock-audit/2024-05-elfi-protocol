import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'MarketProcess',
  libraryNames: [
    'MarketQueryProcess',
    'OracleProcess',
    'Symbol',
    'Market',
    'LpPool',
    'UsdPool',
    'AppConfig',
    'AppTradeConfig',
    'CalUtils',
    'ChainUtils',
    'TokenUtils',
  ],
}

export default createDeployFunction(options)
