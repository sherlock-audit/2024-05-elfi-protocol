import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'LpVault',
  libraryNames: ['TransferUtils'],
  getDeployArgs: async ({ dependencyContracts }) => {
    const { deployer } = await getNamedAccounts()
    return [deployer]
  },
}

export default createDeployFunction(options)