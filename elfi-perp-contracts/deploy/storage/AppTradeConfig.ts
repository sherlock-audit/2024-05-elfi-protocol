import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'AppTradeConfig',
  libraryNames: ['AppStorage', 'AppTradeTokenConfig'],
}

export default createDeployFunction(options)
