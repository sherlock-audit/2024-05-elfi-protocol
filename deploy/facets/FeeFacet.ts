import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'FeeFacet',
  libraryNames: [
    'FeeRewardsProcess',
    'ClaimRewardsProcess',
    'FeeQueryProcess',
    'OracleProcess',
    'GasProcess',
    'ClaimRewards',
  ],
}

export default createDeployFunction(options)
