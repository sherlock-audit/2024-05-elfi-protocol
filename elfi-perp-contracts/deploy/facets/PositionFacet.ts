import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'PositionFacet',
  libraryNames: [
    'OracleProcess',
    'AssetsProcess',
    'DecreasePositionProcess',
    'PositionMarginProcess',
    'GasProcess',
    'ConfigProcess',
    'Account',
    'Position',
    'Symbol',
    'UpdateLeverage',
    'UpdatePositionMargin',
    'UuidCreator',
    'AppConfig',
    'ChainUtils'
  ],
}

export default createDeployFunction(options)
