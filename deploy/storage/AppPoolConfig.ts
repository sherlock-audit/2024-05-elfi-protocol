import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'AppPoolConfig',
  libraryNames: ['AppStorage'],
}

export default createDeployFunction(options)
