import { HardhatRuntimeEnvironment } from 'hardhat/types'

export type RolesConfig = {
  account: string
  roles: string[]
}[]

export default async function (hre: HardhatRuntimeEnvironment): Promise<RolesConfig> {
  const getMainnetRoles = () => {
    return [
      {
        account: 'xxxx',
        roles: ['ADMIN', 'CONFIG', 'KEEPER'],
      },
    ]
  }

  const { deployer } = await hre.getNamedAccounts();
  const [ account0, account1, account2, account3, account4 ] = await hre.getUnnamedAccounts()

  const config: {
    [network: string]: RolesConfig
  } = {
    hardhat: [
      {
        account: deployer,
        roles: ['CONFIG', 'KEEPER'],
      },
      {
        account: account0,
        roles: ['CONFIG', 'KEEPER'],
      },
      {
        account: account1,
        roles: ['CONFIG', 'KEEPER'],
      },
      {
        account: account2,
        roles: ['CONFIG', 'KEEPER'],
      },
      {
        account: account3,
        roles: ['CONFIG', 'KEEPER'],
      },
      {
        account: account4,
        roles: ['CONFIG', 'KEEPER'],
      },
    ],
    dev: [
      {
        account: deployer,
        roles: ['CONFIG', 'KEEPER'],
      },
    ],
    sepolia: [
      {
        account: deployer,
        roles: ['CONFIG', 'KEEPER'],
      },
    ],
  }

  return config[hre.network.name]
}
