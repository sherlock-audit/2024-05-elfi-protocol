import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'OrderFacet',
  libraryNames: [
    'OrderProcess',
    'AssetsProcess',
    'CancelOrderProcess',
    'OracleProcess',
    'GasProcess',
    'VaultProcess',
    'Account',
    'Order',
    'AppConfig',
  ],
}

export default createDeployFunction(options)
