import { DeployFunctionOptions, createDeployFunction } from '../../utils/deploy'

export const options: DeployFunctionOptions = {
  contractName: 'OracleProcess',
  libraryNames: ['OracleFeed', 'OraclePrice', 'AddressUtils'],
}

export default createDeployFunction(options)
