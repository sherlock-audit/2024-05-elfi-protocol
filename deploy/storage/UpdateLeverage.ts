import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'UpdateLeverage',
}

export default createDeployFunction(options)
