import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'MarketFactoryProcess',
  libraryNames: ['LpPool', 'Symbol', 'Market', 'CommonData', 'TransferUtils', 'CalUtils'],
}

export default createDeployFunction(options)
