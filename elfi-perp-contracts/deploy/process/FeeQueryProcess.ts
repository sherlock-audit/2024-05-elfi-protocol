import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'FeeQueryProcess',
  libraryNames: ['FeeRewards', 'LpPool', 'StakingAccount', 'AppConfig', 'CommonData', 'CalUtils'],
}

export default createDeployFunction(options)
