import TokenUtils from 'deploy/utils/TokenUtils'
import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'LiquidationProcess',
  libraryNames: [
    'OracleProcess',
    'DecreasePositionProcess',
    'PositionQueryProcess',
    'AccountProcess',
    'VaultProcess',
    'MarketProcess',
    'Position',
    'Order',
    'Account',
    'Symbol',
    'CommonData',
    'LiabilityClean',
    'UuidCreator',
    'AppConfig',
    'CalUtils',
    'ChainUtils'
  ],
}

export default createDeployFunction(options)
