import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'OrderProcess',
  libraryNames: [
    'IncreasePositionProcess',
    'DecreasePositionProcess',
    'OracleProcess',
    'AccountProcess',
    'AssetsProcess',
    'VaultProcess',
    'PositionQueryProcess',
    'UuidCreator',
    'GasProcess',
    'MarketProcess',
    'Account',
    'Symbol',
    'Order',
    'Position',
    'UsdPool',
    'AppTradeConfig',
    'AppConfig',
    'CalUtils',
    'ChainUtils',
    'TokenUtils'
  ],
}

export default createDeployFunction(options)
