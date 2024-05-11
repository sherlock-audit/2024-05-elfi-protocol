import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'MintProcess',
  libraryNames: [
    'FeeProcess',
    'FeeRewardsProcess',
    'FeeQueryProcess',
    'OracleProcess',
    'LpPoolQueryProcess',
    'VaultProcess',
    'AccountProcess',
    'AssetsProcess',
    'GasProcess',
    'LpPool',
    'UsdPool',
    'StakingAccount',
    'UuidCreator',
    'Mint',
    'CommonData',
    'Account',
    'AppConfig',
    'AppPoolConfig',
    'AppTradeTokenConfig',
    'CalUtils',
    'TokenUtils',
  ],
}

export default createDeployFunction(options)
