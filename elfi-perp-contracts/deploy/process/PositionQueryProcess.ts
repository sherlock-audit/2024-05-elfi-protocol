import TokenUtils from 'deploy/utils/TokenUtils'
import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'PositionQueryProcess',
  libraryNames: [
    'OracleProcess',
    'MarketQueryProcess',
    'Account',
    'Position',
    'Symbol',
    'LpPool',
    'UsdPool',
    'Market',
    'AppTradeConfig',
    'AppTradeTokenConfig',
    'AppConfig',
    'CalUtils',
    'TokenUtils',
    'ChainUtils'
    
  ],
}

export default createDeployFunction(options)
