import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'RedeemProcess',
  libraryNames: [
    'FeeProcess',
    'FeeRewardsProcess',
    'FeeQueryProcess',
    'OracleProcess',
    'LpPoolProcess',
    'LpPoolQueryProcess',
    'VaultProcess',
    'AssetsProcess',
    'MintProcess',
    'GasProcess',
    'LpPool',
    'UsdPool',
    'StakingAccount',
    'UuidCreator',
    'Redeem',
    'CommonData',
    'Account',
    'AppConfig',
    'AppPoolConfig',
    'CalUtils',
    'TokenUtils'
    
  ],
}

export default createDeployFunction(options)
