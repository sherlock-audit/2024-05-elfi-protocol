import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'ConfigFacet',
  libraryNames: ['ConfigProcess'],
}

export default createDeployFunction(options)
