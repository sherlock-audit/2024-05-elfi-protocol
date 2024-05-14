import TokenUtils from 'deploy/utils/TokenUtils'
import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'CancelOrderProcess',
  libraryNames: [
    'OracleProcess',
    'VaultProcess',
    'Account',
    'Order'
  ],
}

export default createDeployFunction(options)
