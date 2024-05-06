import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'ClaimRewardsProcess',
  libraryNames: [
    'OracleProcess',
    'FeeRewardsProcess',
    'VaultProcess',
    'AssetsProcess',
    'GasProcess',
    'StakingAccount',
    'UsdPool',
    'LpPool',
    'CommonData',
    'Symbol',
    'FeeRewards',
    'ClaimRewards',
    'UuidCreator',
    'AppConfig',
    'CalUtils',
    'TokenUtils',
  ],
}

export default createDeployFunction(options)
