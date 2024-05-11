import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'LpPoolProcess',
  libraryNames: ['LpPoolQueryProcess', 'LpPool', 'UsdPool', 'AppPoolConfig', 'CalUtils'],
}

export default createDeployFunction(options)
