import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'FeeRewardsProcess',
  libraryNames: [
    'LpPoolQueryProcess',
    'OracleProcess',
    'TidyRewardsProcess',
    'StakingAccount',
    'UsdPool',
    'LpPool',
    'CommonData',
    'Symbol',
    'FeeRewards',
    'AppPoolConfig',
    'TokenUtils',
    'CalUtils',
  ],
}

export default createDeployFunction(options)
