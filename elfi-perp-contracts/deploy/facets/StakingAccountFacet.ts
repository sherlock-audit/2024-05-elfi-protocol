import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'StakingAccountFacet',
  libraryNames: ['StakingAccount', 'CommonData'],
}

export default createDeployFunction(options)
