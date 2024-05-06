import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'OracleFacet',
  libraryNames: ['OracleProcess'],
}

export default createDeployFunction(options)
