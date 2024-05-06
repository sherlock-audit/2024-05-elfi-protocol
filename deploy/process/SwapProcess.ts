import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'SwapProcess',
  libraryNames: ['VaultProcess', 'OracleProcess', 'AppTradeConfig', 'AppConfig', 'CalUtils', 'TokenUtils'],
}

export default createDeployFunction(options)
