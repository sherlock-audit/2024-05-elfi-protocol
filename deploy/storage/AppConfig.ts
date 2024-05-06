import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'AppConfig',
  libraryNames: ['AppStorage'],
}

export default createDeployFunction(options)
