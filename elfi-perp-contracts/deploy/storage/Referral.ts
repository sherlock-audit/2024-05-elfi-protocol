import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'Referral',
  libraryNames: ['AppStorage'],
}

export default createDeployFunction(options)
