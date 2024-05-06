import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'LpPool',
  libraryNames: ['CalUtils', 'ChainUtils', 'AppPoolConfig'],
}

export default createDeployFunction(options)
