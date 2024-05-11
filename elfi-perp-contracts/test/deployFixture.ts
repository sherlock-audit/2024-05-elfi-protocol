import { precision } from '@utils/precision'
import { ethers, deployments } from 'hardhat'
import {
  AccountFacet,
  ConfigFacet,
  Diamond,
  FaucetFacet,
  FeeFacet,
  LiquidationFacet,
  LpVault,
  MarketFacet,
  MarketManagerFacet,
  MockToken,
  OracleFacet,
  OrderFacet,
  PoolFacet,
  PortfolioVault,
  PositionFacet,
  RebalanceFacet,
  StakeFacet,
  StakingAccountFacet,
  SwapFacet,
  TradeVault,
  VaultFacet,
  WETH,
} from 'types'

export type Fixture = Awaited<ReturnType<typeof deployFixture>>

export async function deployFixture() {
  await deployments.fixture()
  const chainId = 31337

  const accountList = await ethers.getSigners()
  const [
    wallet,
    user0,
    user1,
    user2,
    user3,
    user4,
    user5,
    user6,
    user7,
    user8,
    signer0,
    signer1,
    signer2,
    signer3,
    signer4,
    signer5,
    signer6,
    signer7,
    signer8,
    signer9,
  ] = accountList
  // const eth = await ethers.getContract<MockToken>('ETH')

  const [weth, wbtc, sol, usdc, tradeVault, lpVault, portfolioVault, diamond] =
    await Promise.all([
      ethers.getContract<WETH>('WETH'),
      ethers.getContract<MockToken>('WBTC'),
      ethers.getContract<MockToken>('SOL'),
      ethers.getContract<MockToken>('USDC'),
      ethers.getContract<TradeVault>('TradeVault'),
      ethers.getContract<LpVault>('LpVault'),
      ethers.getContract<PortfolioVault>('PortfolioVault'),
      ethers.getContract<Diamond>('Diamond'),
    ])

  const diamondAddr = await diamond.getAddress()

  const getFacet = <T>(name: string) => ethers.getContractAt(name, diamondAddr) as Promise<T>

  const [
    marketManagerFacet,
    orderFacet,
    poolFacet,
    marketFacet,
    stakeFacet,
    oracleFacet,
    swapFacet,
    stakingAccountFacet,
    feeFacet,
    liquidationFacet,
    accountFacet,
    positionFacet,
    configFacet,
    vaultFacet,
    faucetFacet,
    rebalanceFacet
  ] = await Promise.all([
    getFacet<MarketManagerFacet>('MarketManagerFacet'),
    getFacet<OrderFacet>('OrderFacet'),
    getFacet<PoolFacet>('PoolFacet'),
    getFacet<MarketFacet>('MarketFacet'),
    getFacet<StakeFacet>('StakeFacet'),
    getFacet<OracleFacet>('OracleFacet'),
    getFacet<SwapFacet>('SwapFacet'),
    getFacet<StakingAccountFacet>('StakingAccountFacet'),
    getFacet<FeeFacet>('FeeFacet'),
    getFacet<LiquidationFacet>('LiquidationFacet'),
    getFacet<AccountFacet>('AccountFacet'),
    getFacet<PositionFacet>('PositionFacet'),
    getFacet<ConfigFacet>('ConfigFacet'),
    getFacet<VaultFacet>('VaultFacet'),
    getFacet<FaucetFacet>('FaucetFacet'),
    getFacet<RebalanceFacet>('RebalanceFacet'),
  ])

  const btcUsd = ethers.encodeBytes32String('BTCUSD')
  const ethUsd = ethers.encodeBytes32String('ETHUSD')
  const solUsd = ethers.encodeBytes32String('SOLUSD')

  const [ethUsdSymbol, solUsdSymbol, btcUsdSymbol] = await Promise.all([
    marketFacet.getSymbol(ethUsd),
    marketFacet.getSymbol(solUsd),
    marketFacet.getSymbol(btcUsd),
  ])

  const xSol = solUsdSymbol.stakeToken
  const xBtc = btcUsdSymbol.stakeToken
  const xEth = ethUsdSymbol.stakeToken

  const xUsd = await marketFacet.getStakeUsdToken()

  await Promise.all([

    weth.connect(wallet).deposit({ value: precision.token(2_000) }),

    wbtc.mint(user0.address, precision.token(10_000)),
    sol.mint(user0.address, precision.token(10_000)),
    weth.connect(user0).deposit({ value: precision.token(2_000) }),
    usdc.mint(user0.address, precision.token(1_000_000, 6)),

    wbtc.mint(user1.address, precision.token(10_000)),
    sol.mint(user1.address, precision.token(10_000)),
    weth.connect(user1).deposit({ value: precision.token(2_000) }),
    usdc.mint(user1.address, precision.token(1_000_000, 6)),

    wbtc.mint(user2.address, precision.token(10_000)),
    sol.mint(user2.address, precision.token(10_000)),
    weth.connect(user2).deposit({ value: precision.token(2_000) }),
    usdc.mint(user2.address, precision.token(1_000_000, 6)),

    wbtc.mint(user3.address, precision.token(10_000)),
    sol.mint(user3.address, precision.token(10_000)),
    weth.connect(user3).deposit({ value: precision.token(2_000) }),
    usdc.mint(user3.address, precision.token(1_000_000, 6)),
  ])

  const accounts = {
    wallet,
    user0,
    user1,
    user2,
    user3,
    user4,
    user5,
    user6,
    user7,
    user8,
    signer0,
    signer1,
    signer2,
    signer3,
    signer4,
    signer5,
    signer6,
    signer7,
    signer8,
    signer9,
    signers: [signer0, signer1, signer2, signer3, signer4, signer5, signer6],
  }

  const tokens = {
    weth,
    sol,
    wbtc,
    usdc,
  }

  const contracts = {
    tradeVault,
    lpVault,
    diamond,
    marketManagerFacet,
    marketFacet,
    poolFacet,
    stakeFacet,
    orderFacet,
    oracleFacet,
    stakingAccountFacet,
    feeFacet,
    accountFacet,
    positionFacet,
    liquidationFacet,
    configFacet,
    swapFacet,
    vaultFacet,
    faucetFacet,
    rebalanceFacet
  }

  const symbols = {
    btcUsd,
    ethUsd,
    solUsd,
  }

  const pools = {
    xBtc,
    xEth,
    xUsd,
    xSol,
  }

  const [
    wbtcAddr,
    wethAddr,
    solAddr,
    usdcAddr,
    tradeVaultAddr,
    lpVaultAddr,
    portfolioVaultAddr,
  ] = await Promise.all([
    wbtc.getAddress(),
    weth.getAddress(),
    sol.getAddress(),
    usdc.getAddress(),
    tradeVault.getAddress(),
    lpVault.getAddress(),
    portfolioVault.getAddress(),
  ])

  const addresses = {
    diamondAddr,
    tradeVaultAddr,
    lpVaultAddr,

    portfolioVaultAddr,
    wbtcAddr,
    wethAddr,
    solAddr,
    usdcAddr,
  }

  return {
    getContract: async (name: string) => {
      return await ethers.getContractAt(name, diamondAddr)
    },

    accounts,
    tokens,
    contracts,
    symbols,
    pools,
    addresses,

    ...accounts,
    ...tokens,
    ...contracts,
    ...symbols,
    ...pools,
    ...addresses,
  }
}
