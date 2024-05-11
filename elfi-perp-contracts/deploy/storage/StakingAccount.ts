import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'StakingAccount',
  libraryNames: ['LpPool'],
}

export default createDeployFunction(options)
