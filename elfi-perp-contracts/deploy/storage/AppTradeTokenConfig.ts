import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'AppTradeTokenConfig',
  libraryNames: ['AppStorage'],
}

export default createDeployFunction(options)
