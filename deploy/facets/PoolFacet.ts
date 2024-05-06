import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'PoolFacet',
  libraryNames: ['LpPoolQueryProcess', 'OracleProcess', 'AddressUtils', 'CommonData', 'LpPool', 'UsdPool'],
}

export default createDeployFunction(options)
