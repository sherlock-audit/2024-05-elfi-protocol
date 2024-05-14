import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { VaultConfig } from 'config/vaults'

const func = async ({ deployments, elfi, network }: HardhatRuntimeEnvironment) => {
  if (!['localhost', 'hardhat', 'dev', 'sepolia'].includes(network.name)) {
    return
  }

  const vaultConfigs: Record<string, VaultConfig> = await elfi.getVaults()

  for (const [vault, config] of Object.entries(vaultConfigs)) {
    if (!config.deploy) {
      continue
    }
    const vaultAddr = await deployments.get(vault)
    vaultConfigs[vault].address = vaultAddr.address
  }
}

func.tags = ['Vaults']
func.dependencies = ['LpVault', 'TradeVault', 'PortfolioVault']
export default func
