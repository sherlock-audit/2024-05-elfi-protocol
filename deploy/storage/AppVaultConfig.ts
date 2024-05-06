import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'AppVaultConfig',
  libraryNames: ['AppStorage'],
}

export default createDeployFunction(options)
