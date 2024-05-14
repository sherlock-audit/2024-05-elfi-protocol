import TokenUtils from 'deploy/utils/TokenUtils'
import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'DecreasePositionProcess',
  libraryNames: [
    'MarketProcess',
    'CancelOrderProcess',
    'LpPoolProcess',
    'FeeProcess',
    'FeeQueryProcess',
    'OracleProcess',
    'VaultProcess',
    'PositionMarginProcess',
    'PositionQueryProcess',
    'Account',
    'Position',
    'Symbol',
    'FeeRewards',
    'InsuranceFund',
    'CommonData',
    'AppConfig',
    'AppTradeConfig',
    'CalUtils',
    'TokenUtils',
    'ChainUtils',
    
  ],
}

export default createDeployFunction(options)
