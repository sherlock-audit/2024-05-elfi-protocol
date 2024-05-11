import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'FaucetFacet',
  libraryNames: ['VaultProcess', 'RoleAccessControl'],
}

export default createDeployFunction(options)
