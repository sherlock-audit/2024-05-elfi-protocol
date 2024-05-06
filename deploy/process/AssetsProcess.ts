import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'AssetsProcess',
  libraryNames: [
    'AccountProcess',
    'PositionMarginProcess',
    'VaultProcess',
    'OracleProcess',
    'Account',
    'CommonData',
    'Order',
    'Position',
    'AppConfig',
    'AppTradeTokenConfig',
    'UuidCreator',
    'Withdraw',
    'CalUtils',
    'TokenUtils',
    'TransferUtils',
  ],
}

export default createDeployFunction(options)
