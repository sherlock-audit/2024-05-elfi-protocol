import { createDeployFunction } from '../../utils/deploy'

export default createDeployFunction({
  contractName: 'StakeToken',
  libraryNames: ['TransferUtils'],
  getDeployArgs: async ({ dependencyContracts }) => {
    const { deployer } = await getNamedAccounts()
    return ['xStake', 18, deployer]
  },
})
