import TokenUtils from 'deploy/utils/TokenUtils'
import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'PositionMarginProcess',
  libraryNames: [
    'LpPoolProcess',
    'OracleProcess',
    'VaultProcess',
    'AccountProcess',
    'UuidCreator',
    'UpdatePositionMargin',
    'UpdateLeverage',
    'Account',
    'Position',
    'Symbol',
    'Order',
    'AppConfig',
    'AppTradeConfig',
    'CalUtils',
    'TokenUtils',
    'ChainUtils',
  ],
}

export default createDeployFunction(options)
