import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'RebalanceFacet',
  libraryNames: ['RebalanceProcess', 'OracleProcess', 'GasProcess'],
}

export default createDeployFunction(options)