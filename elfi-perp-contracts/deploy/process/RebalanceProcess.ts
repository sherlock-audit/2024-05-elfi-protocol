import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'RebalanceProcess',
  libraryNames: [
    'VaultProcess',
    'OracleProcess',
    'SwapProcess',
    'LpPool',
    'UsdPool',
    'CommonData',
    'AppTradeConfig',
    'CalUtils',
    'TokenUtils',
  ],
}

export default createDeployFunction(options)
