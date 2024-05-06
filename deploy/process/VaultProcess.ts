import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'VaultProcess',
  libraryNames: ['AppConfig'],
}

export default createDeployFunction(options)
