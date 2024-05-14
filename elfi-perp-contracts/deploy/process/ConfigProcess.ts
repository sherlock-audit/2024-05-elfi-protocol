import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'ConfigProcess',
  libraryNames: ['AppStorage', 'AppConfig', 'AppTradeConfig', 'AppPoolConfig', 'UsdPool'],
}

export default createDeployFunction(options)