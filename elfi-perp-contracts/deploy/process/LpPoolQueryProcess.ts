import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'LpPoolQueryProcess',
  libraryNames: ['OracleProcess', 'LpPool', 'UsdPool', 'Market', 'Symbol', 'CommonData', 'CalUtils', 'TokenUtils'],
}

export default createDeployFunction(options)
