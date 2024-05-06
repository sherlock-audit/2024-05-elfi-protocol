import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'MarketManagerFacet',
  libraryNames: ['MarketFactoryProcess', 'OracleProcess', 'ConfigProcess', 'AddressUtils', 'TypeUtils'],
}

export default createDeployFunction(options)
