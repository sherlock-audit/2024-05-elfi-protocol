import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'StakeFacet',
  libraryNames: [
    'MintProcess',
    'RedeemProcess',
    'AssetsProcess',
    'GasProcess',
    'OracleProcess',
    'VaultProcess',
    'AddressUtils',
    'Account',
    'LpPool',
    'Mint',
    'Redeem',
    'CommonData',
    'UuidCreator',
    'UsdPool',
  ],
}

export default createDeployFunction(options)
