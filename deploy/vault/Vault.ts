import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'Vault',
  libraryNames: ['TransferUtils'],
  getDeployArgs: async ({ dependencyContracts }) => {
    const { deployer } = await getNamedAccounts()
    return [deployer]
  },
}

export default createDeployFunction(options)
