import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'UpdatePositionMargin',
}

export default createDeployFunction(options)
