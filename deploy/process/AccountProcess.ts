import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'AccountProcess',
  libraryNames: [
    'OracleProcess',
    'PositionQueryProcess',
    'Account',
    'AppTradeTokenConfig',
    'CalUtils',
    'TokenUtils',
  ],
}

export default createDeployFunction(options)
