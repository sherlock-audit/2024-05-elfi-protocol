import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'MarketFacet',
  libraryNames: ['MarketQueryProcess', 'ConfigProcess', 'Symbol', 'CommonData', 'UuidCreator'],
}

export default createDeployFunction(options)
