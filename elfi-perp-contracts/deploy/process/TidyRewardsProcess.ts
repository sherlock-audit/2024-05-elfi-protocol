import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'TidyRewardsProcess',
  libraryNames: [
    'OracleProcess',
    'VaultProcess',
    'UsdPool',
    'LpPool',
    'CommonData',
    'AppTradeConfig',
    'FeeRewards',
    'TokenUtils',
    'CalUtils',
  ],
}

export default createDeployFunction(options)
