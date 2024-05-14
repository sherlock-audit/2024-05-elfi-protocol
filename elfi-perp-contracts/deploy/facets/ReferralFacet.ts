import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'ReferralFacet',
  libraryNames: ['Referral'],
}

export default createDeployFunction(options)
