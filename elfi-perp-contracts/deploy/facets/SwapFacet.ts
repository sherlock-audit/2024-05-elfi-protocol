import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'SwapFacet',
  libraryNames: [
    'SwapProcess',
    'AssetsProcess',
    'OracleProcess',
    'Account',
    'AppTradeConfig',
    'CalUtils',
    'TokenUtils',
  ],
}

export default createDeployFunction(options)
