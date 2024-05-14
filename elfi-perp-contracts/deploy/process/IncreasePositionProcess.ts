import TokenUtils from 'deploy/utils/TokenUtils'
import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'IncreasePositionProcess',
  libraryNames: [
    'MarketProcess',
    'LpPoolProcess',
    'FeeProcess',
    'FeeQueryProcess',
    'MarketQueryProcess',
    'Account',
    'Position',
    'Symbol',
    'FeeRewards',
    'AppTradeConfig',
    'AppConfig',
    'CalUtils',
    'TokenUtils',
    'ChainUtils',
  ],
}

export default createDeployFunction(options)
