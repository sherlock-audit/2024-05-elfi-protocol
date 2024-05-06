import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'VaultFacet',
  libraryNames: ['AppVaultConfig'],
}

export default createDeployFunction(options)
