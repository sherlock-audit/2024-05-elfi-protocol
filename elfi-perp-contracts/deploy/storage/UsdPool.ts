import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'UsdPool',
  libraryNames: ['CalUtils', 'ChainUtils', 'TokenUtils', 'AppPoolConfig'],
}

export default createDeployFunction(options)
