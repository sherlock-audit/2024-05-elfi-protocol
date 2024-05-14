import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'Account',
  libraryNames: ['CommonData', 'AppTradeTokenConfig'],
}

export default createDeployFunction(options)
