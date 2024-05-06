import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { precision } from '@utils/precision'
import { handleMint } from '@utils/mint'
import {
  AccountFacet,
  ConfigFacet,
  FeeFacet,
  MarketFacet,
  MockToken,
  OrderFacet,
  PoolFacet,
  PositionFacet,
  SwapFacet,
  TradeVault,
  VaultFacet,
} from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { handleOrder } from '@utils/order'
import { OrderSide, PositionSide } from '@utils/constants'
import { deposit } from '@utils/deposit'
import { oracles } from '@utils/oracles'
import { account } from '@utils/account'
import { addPoolLiquidation, createPool, deployUniswapV3 } from '@utils/uniswap'
import { ethers } from 'hardhat'
import exp from 'constants'

describe('Swap Test', function () {
  let fixture: Fixture
  let tradeVault: TradeVault,
    marketFacet: MarketFacet,
    accountFacet: AccountFacet,
    positionFacet: PositionFacet,
    vaultFacet: VaultFacet,
    swapFacet: SwapFacet,
    configFacet: ConfigFacet

  let deployer: HardhatEthersSigner, user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner, user3: HardhatEthersSigner
  let diamondAddr: string, tradeVaultAddr: string, nftPositionManagerAddr:string, wbtcAddr: string, wethAddr: string, solAddr: string, usdcAddr: string
  let btcUsd: string, ethUsd: string, solUsd: string, xBtc: string, xEth: string, xSol: string, xUsd: string
  let wbtc: MockToken, weth: MockToken, sol: MockToken, usdc: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ tradeVault, marketFacet, accountFacet, positionFacet, vaultFacet, swapFacet, configFacet } = fixture.contracts)
    ;({ user0, user1, user2, user3 } = fixture.accounts)
    ;({ btcUsd, ethUsd, solUsd } = fixture.symbols)
    ;({ xBtc, xEth, xSol, xUsd } = fixture.pools)
    ;({ wbtc, weth, sol, usdc } = fixture.tokens)
    ;({ diamondAddr, tradeVaultAddr } = fixture.addresses)
    wbtcAddr = await wbtc.getAddress()
    wethAddr = await weth.getAddress()
    solAddr = await sol.getAddress()
    usdcAddr = await usdc.getAddress()

    const btcTokenPrice = precision.price(65000)
    const btcOracle = [{ token: wbtcAddr, minPrice: btcTokenPrice, maxPrice: btcTokenPrice }]
    await handleMint(fixture, {
      stakeToken: xBtc,
      requestToken: wbtc,
      requestTokenAmount: precision.token(100),
      oracle: btcOracle,
    })

    const ethTokenPrice = precision.price(3600)
    const ethOracle = [{ token: wethAddr, minPrice: ethTokenPrice, maxPrice: ethTokenPrice }]
    await handleMint(fixture, {
      requestTokenAmount: precision.token(1000),
      oracle: ethOracle,
    })

    const solTokenPrice = precision.price(160)
    const solOracle = [{ token: solAddr, minPrice: solTokenPrice, maxPrice: solTokenPrice }]
    await handleMint(fixture, {
      stakeToken: xSol,
      requestToken: sol,
      requestTokenAmount: precision.token(1000),
      oracle: solOracle,
    })

    const usdcTokenPrice = precision.price(101, 6)
    const usdOracle = [{ token: usdcAddr, minPrice: usdcTokenPrice, maxPrice: usdcTokenPrice }]

    await handleMint(fixture, {
      requestTokenAmount: precision.token(100000, 6),
      stakeToken: xUsd,
      requestToken: usdc,
      oracle: usdOracle,
    })

    const [deployer1] = await ethers.getSigners()
    deployer = deployer1
    const [factoryAddr, weth9Addr, routerAddr, nftPositionManagerAddr1] = await deployUniswapV3(deployer)
    nftPositionManagerAddr = nftPositionManagerAddr1
    await configFacet.setUniswapRouter(routerAddr)
    await createPool(deployer, factoryAddr, nftPositionManagerAddr, sol, usdc, 170)
  })

  it('Case0: Swap SOL to USDC', async function () {
    const amount = precision.token(10, 9)
    await deposit(fixture, {
      account: user0,
      token: sol,
      amount: amount,
    })

    const orderMarginInUsd0 = precision.usd(999) // 999$
    const solPrice0 = precision.price(150)
    const usdcPrice0 = precision.price(99, 6)
    const oracle0 = [
      { token: solAddr, minPrice: solPrice0, maxPrice: solPrice0 },
      { token: usdcAddr, minPrice: usdcPrice0, maxPrice: usdcPrice0 },
    ]

    await handleOrder(fixture, {
      orderMargin: orderMarginInUsd0,
      marginToken: usdc,
      symbol: solUsd,
      orderSide: OrderSide.SHORT,
      oracle: oracle0,
      isCrossMargin: true,
      leverage: precision.rate(10),
    })

    const symbolInfo = await marketFacet.getSymbol(solUsd)
    const orderMargin0 = precision.usdToToken(orderMarginInUsd0, usdcPrice0, 6)
    const openFee0 = precision.mulRate(orderMargin0 * BigInt(10), symbolInfo.config.openFeeRate)
    const initialMargin0 = orderMargin0 - openFee0
    const positionInfo = await positionFacet.getSinglePosition(user0.address, solUsd, usdcAddr, true)
    const accountInfo0 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle0))
    expect(openFee0).to.equals(account.getAccountTokenLiability(accountInfo0, usdcAddr))

    const solPrice1 = solPrice0 + precision.price(20)
    const usdcPrice1 = usdcPrice0
    const oracle1 = [
      { token: solAddr, minPrice: solPrice1, maxPrice: solPrice1 },
      { token: usdcAddr, minPrice: usdcPrice1, maxPrice: usdcPrice1 },
    ]

    await handleOrder(fixture, {
      symbol: solUsd,
      orderSide: OrderSide.LONG,
      posSide: PositionSide.DECREASE,
      marginToken: usdc,
      isCrossMargin: true,
      qty: positionInfo.qty,
      oracle: oracle1,
    })

    const accountInfo1 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle1))
    const totalLiability = account.getAccountTokenLiability(accountInfo1, usdcAddr)
    console.log('totalLiability', totalLiability)
    const portfolioAddress = await vaultFacet.getPortfolioVaultAddress()

    const solBalancePortfolioVault0 = await sol.balanceOf(portfolioAddress)
    const usdcBalancePortfolioVault0 = await usdc.balanceOf(portfolioAddress)
    // await addPoolLiquidation(deployer, nftPositionManagerAddr, sol, usdc, 170)
    await swapFacet.connect(user3).swapPortfolioToPayLiability([user0.address], [[usdcAddr]], oracles.format(oracle1))
    const solBalancePortfolioVault1 = await sol.balanceOf(portfolioAddress)
    const usdcBalancePortfolioVault1 = await usdc.balanceOf(portfolioAddress)
    const accountInfo2 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle1))

    expect(0).to.be.equals(account.getAccountTokenLiability(accountInfo2, usdcAddr))

    console.log("pre solBalance", account.getAccountTokenAmount(accountInfo1, solAddr))
    console.log("after solBalance", account.getAccountTokenAmount(accountInfo2, solAddr))
    console.log("pre usdcBalance", account.getAccountTokenAmount(accountInfo1, usdcAddr))
    console.log("after usdcBalance", account.getAccountTokenAmount(accountInfo2, usdcAddr))
    console.log("solBalancePortfolioVault0", solBalancePortfolioVault0)
    console.log("solBalancePortfolioVault1", solBalancePortfolioVault1)
    console.log("usdcBalancePortfolioVault0", usdcBalancePortfolioVault0)
    console.log("usdcBalancePortfolioVault1", usdcBalancePortfolioVault1)

    const usedSol = account.getAccountTokenAmount(accountInfo1, solAddr) - account.getAccountTokenAmount(accountInfo2, solAddr)
    expect(usedSol).to.be.equals(solBalancePortfolioVault0 - solBalancePortfolioVault1)

    const userAddUsdc = account.getAccountTokenAmount(accountInfo2, usdcAddr) - account.getAccountTokenAmount(accountInfo1, usdcAddr)
    expect(userAddUsdc + totalLiability).to.be.equals(usdcBalancePortfolioVault1 - usdcBalancePortfolioVault0)

  })
})
