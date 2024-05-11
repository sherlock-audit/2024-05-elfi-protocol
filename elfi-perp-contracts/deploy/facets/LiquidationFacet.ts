import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'LiquidationFacet',
  libraryNames: [
    'LiquidationProcess',
    'AssetsProcess',
    'VaultProcess',
    'GasProcess',
    'OracleProcess',
    'InsuranceFund',
    'LiabilityClean',
  ],
}

export default createDeployFunction(options)
