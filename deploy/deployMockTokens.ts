import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { ethers } from 'hardhat'
import { TokenConfig } from '../config/tokens'
import { precision } from '@utils/precision'

const func = async ({ getNamedAccounts, deployments, elfi, network }: HardhatRuntimeEnvironment) => {
  if (!['localhost', 'hardhat', 'dev'].includes(network.name)) {
    return
  }

  console.log('deploy MockTokens')
  const { deploy, log } = deployments
  const { deployer } = await getNamedAccounts()
  const tokens: Record<string, TokenConfig> = await elfi.getTokens()

  for (const [tokenSymbol, token] of Object.entries(tokens)) {
    if (!token.deploy) {
      if (token.wrapper && ['localhost', 'hardhat'].includes(network.name)) {
        tokens[tokenSymbol].address = await (await ethers.getContract('WETH')).getAddress()
      }
      continue
    }

    if (network.live) {
      console.warn('WARN: Deploying token on live network')
    }

    const existingToken = await deployments.getOrNull(tokenSymbol)
    if (existingToken) {
      log(`Reusing ${tokenSymbol} at ${existingToken.address}`)
      console.warn(`WARN: bytecode diff is not checked`)
      tokens[tokenSymbol].address = existingToken.address
      continue
    }

    const { address, newlyDeployed } = await deploy(tokenSymbol, {
      from: deployer,
      log: true,
      contract: 'MockToken',
      args: [tokenSymbol, token.decimals],
    })
    console.log('token:', tokenSymbol, address)
    tokens[tokenSymbol].address = address
    if (newlyDeployed) {
      const tokenContract = await ethers.getContractAt('MockToken', address)
      await tokenContract.mint(deployer, precision.pow(1000000000, token.decimals))
    }
  }
}

func.tags = ['Tokens']
func.dependencies = ['MockToken', 'WETH']
export default func
