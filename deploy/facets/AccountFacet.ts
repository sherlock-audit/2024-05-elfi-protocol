import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'AccountFacet',
  libraryNames: [
    'AccountProcess',
    'AssetsProcess',
    'OracleProcess',
    'Account',
    'Withdraw',
    'AppConfig',
    'AppTradeTokenConfig',
    'AddressUtils',
  ],
}

export default createDeployFunction(options)
