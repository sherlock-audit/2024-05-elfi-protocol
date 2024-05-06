import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'MarketQueryProcess',
  libraryNames: [
    'LpPoolQueryProcess',
    'OracleProcess',
    'Symbol',
    'Market',
    'AppPoolConfig',
    'AppTradeConfig',
    'LpPool',
    'UsdPool',
    'CommonData',
    'CalUtils',
    'ChainUtils',
    'TokenUtils'
  ],
}

export default createDeployFunction(options)
