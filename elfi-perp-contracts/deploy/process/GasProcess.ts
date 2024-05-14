import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'GasProcess',
  libraryNames: ['VaultProcess', 'CommonData', 'AppConfig'],
}

export default createDeployFunction(options)
