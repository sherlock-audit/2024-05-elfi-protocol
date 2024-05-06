import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { ORDER_ID_KEY, OrderSide, OrderType, PositionSide, StopType } from '@utils/constants'
import { precision } from '@utils/precision'
import {
  AccountFacet,
  ConfigProcess,
  FeeFacet,
  MarketFacet,
  MockToken,
  OrderFacet,
  PoolFacet,
  PositionFacet,
  TradeVault,
} from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { ethers } from 'hardhat'
import { Contract, ZeroAddress } from 'ethers'
import { handleOrder } from '@utils/order'
import { handleMint } from '@utils/mint'
import { account } from '@utils/account'
import { deposit } from '@utils/deposit'
import { pool } from '@utils/pool'
import { configs } from '@utils/configs'
import { ConfigFacet, IConfig } from 'types/contracts/facets/ConfigFacet'
import { oracles } from '@utils/oracles'

describe('Increase Market Order Cross Margin Process', function () {
  let fixture: Fixture
  let tradeVault: TradeVault,
    marketFacet: MarketFacet,
    orderFacet: OrderFacet,
    poolFacet: PoolFacet,
    accountFacet: AccountFacet,
    positionFacet: PositionFacet,
    feeFacet: FeeFacet,
    configFacet: ConfigFacet
  let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner, user3: HardhatEthersSigner
  let diamondAddr: string,
    lpVaultAddr: string,
    tradeVaultAddr: string,
    portfolioVaultAddr: string,
    wbtcAddr: string,
    wethAddr: string,
    usdcAddr: string
  let btcUsd: string, ethUsd: string, xBtc: string, xEth: string, xUsd: string
  let wbtc: MockToken, weth: MockToken, usdc: MockToken
  let config: IConfig.CommonConfigParamsStructOutput

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ tradeVault, marketFacet, poolFacet, orderFacet, accountFacet, positionFacet, feeFacet, configFacet } =
      fixture.contracts)
    ;({ user0, user1, user2, user3 } = fixture.accounts)
    ;({ btcUsd, ethUsd } = fixture.symbols)
    ;({ xBtc, xEth, xUsd } = fixture.pools)
    ;({ wbtc, weth, usdc } = fixture.tokens)
    ;({ diamondAddr, lpVaultAddr, tradeVaultAddr, portfolioVaultAddr } = fixture.addresses)
    wbtcAddr = await wbtc.getAddress()
    wethAddr = await weth.getAddress()
    usdcAddr = await usdc.getAddress()
    config = await configFacet.getConfig()

    const btcTokenPrice = precision.price(25000)
    const btcOracle = [{ token: wbtcAddr, minPrice: btcTokenPrice, maxPrice: btcTokenPrice }]
    await handleMint(fixture, {
      stakeToken: xBtc,
      requestToken: wbtc,
      requestTokenAmount: precision.token(100),
      oracle: btcOracle,
    })

    const ethTokenPrice = precision.price(1600)
    const ethOracle = [{ token: wethAddr, minPrice: ethTokenPrice, maxPrice: ethTokenPrice }]
    await handleMint(fixture, {
      requestTokenAmount: precision.token(1000),
      oracle: ethOracle,
    })

    const usdtTokenPrice = precision.price(1)
    const usdcTokenPrice = precision.price(101, 6)
    const daiTokenPrice = precision.price(99, 7)
    const usdOracle = [
      { token: usdcAddr, minPrice: usdcTokenPrice, maxPrice: usdcTokenPrice },
    ]

    await handleMint(fixture, {
      requestTokenAmount: precision.token(100000, 6),
      stakeToken: xUsd,
      requestToken: usdc,
      oracle: usdOracle,
    })

  })

  it('Case1: Place Single Market Order Single User/USDC/btcUsd/Long', async function () {
    const preTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const preVaultBalance = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    // const preTotalFee = await feeFacet.getTokenFee(xBtc, wbtcAddr)

    const usdcAmount = precision.token(2000, 6)
    await deposit(fixture, {
      account: user0,
      token: usdc,
      amount: usdcAmount,
    })

    const nextTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await usdc.balanceOf(portfolioVaultAddr))

    expect(-usdcAmount).to.equals(nextTokenBalance - preTokenBalance)
    expect(usdcAmount).to.equals(nextVaultBalance - preVaultBalance)

    const orderMargin = precision.token(999) // 999$
    usdc.connect(user0).approve(diamondAddr, orderMargin)
    const executionFee = precision.token(2, 15)
    const tx = await orderFacet.connect(user0).createOrderRequest(
      {
        symbol: btcUsd,
        orderSide: OrderSide.LONG,
        posSide: PositionSide.INCREASE,
        orderType: OrderType.MARKET,
        stopType: StopType.NONE,
        isCrossMargin: true,
        marginToken: wbtcAddr,
        qty: 0,
        leverage: precision.rate(10),
        triggerPrice: 0,
        acceptablePrice: precision.price(26000),
        executionFee: executionFee,
        placeTime: 0,
        orderMargin: orderMargin,
        isNativeToken: false,
      },
      {
        value: executionFee,
      },
    )

    await tx.wait()

    const nextTokenBalance0 = BigInt(await usdc.balanceOf(user0.address))
    const nextVaultBalance0 = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    const nextMarketBalance0 = BigInt(await usdc.balanceOf(xBtc))

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance0 - nextVaultBalance)
    expect(0).to.equals(nextTokenBalance0 - nextTokenBalance)

    // Account
    const accountInfo = await accountFacet.getAccountInfo(user0.address)
    expect(user0.address).to.equals(accountInfo.owner)
    expect(orderMargin).to.equals(accountInfo.orderHoldInUsd)
    expect(usdcAmount).to.equals(account.getAccountTokenBalance(accountInfo, usdcAddr)?.amount)
    expect(0).to.equals(account.getAccountTokenBalance(accountInfo, usdcAddr)?.usedAmount)

    // Order
    const orders = await orderFacet.getAccountOrders(user0.address)
    expect(1).to.equals(orders.length)
    expect(user0.address).to.equals(orders[0].orderInfo.account)
    expect(true).to.equals(orders[0].orderInfo.isCrossMargin)
    expect(OrderType.MARKET).to.equals(orders[0].orderInfo.orderType)
    expect(btcUsd).to.equals(orders[0].orderInfo.symbol)
    expect(wbtcAddr).to.equals(orders[0].orderInfo.marginToken)

    const requestId = await marketFacet.getLastUuid(ORDER_ID_KEY)

    const tokenPrice = precision.price(25000)
    const usdcPrice = precision.price(99, 6) // 0.99$
    const oracle = [
      { token: wbtcAddr, targetToken: ethers.ZeroAddress, minPrice: tokenPrice, maxPrice: tokenPrice },
      { token: usdcAddr, targetToken: ethers.ZeroAddress, minPrice: usdcPrice, maxPrice: usdcPrice },
    ]

    await orderFacet.connect(user3).executeOrder(requestId, oracle)

    const symbolInfo = await marketFacet.getSymbol(btcUsd)
    const nextVaultBalance1 = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    const nextMarketBalance1 = BigInt(await usdc.balanceOf(xBtc))

    const tokenOrderMargin = precision.divPrice(orderMargin, tokenPrice)
    const leverageMargin = precision.mulRate(tokenOrderMargin, precision.rate(10))
    const tradeFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = tokenOrderMargin - tradeFee

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance1 - nextVaultBalance0)
    expect(0).to.equals(nextMarketBalance1 - nextMarketBalance0)

    // pool
    const poolInfo = await poolFacet.getPool(xBtc)
    expect(initialMargin * BigInt(10 - 1)).to.equals(poolInfo.baseTokenBalance.holdAmount)

    // Account
    const accountInfo2 = await accountFacet.getAccountInfo(user0.address)
    expect(0).to.equals(account.getAccountTokenBalance(accountInfo2, wbtcAddr)?.amount)
    expect(0).to.equals(accountInfo2.orderHoldInUsd)
    expect(initialMargin + tradeFee).to.equals(account.getAccountTokenBalance(accountInfo2, wbtcAddr)?.usedAmount)
    expect(tradeFee).to.equals(account.getAccountTokenBalance(accountInfo2, wbtcAddr)?.liability)

    // Position
    const positionInfo = await positionFacet.getSinglePosition(user0.address, btcUsd, wbtcAddr, true)
    expect(initialMargin).to.equals(positionInfo.initialMargin)
    expect(initialMargin * BigInt(25000)).to.equals(positionInfo.initialMarginInUsd)
    expect(0).to.equals(positionInfo.initialMarginInUsdFromBalance)
    expect(precision.rate(10)).to.equals(positionInfo.leverage)
    expect(tokenPrice).to.equals(positionInfo.entryPrice)
    expect(btcUsd).to.equals(positionInfo.symbol)
    expect(wbtcAddr).to.equals(positionInfo.marginToken)
    expect(symbolInfo.indexToken).to.equals(positionInfo.indexToken)
    expect(true).to.equals(positionInfo.isLong)
    expect(initialMargin * BigInt(10) * BigInt(25000)).to.equals(positionInfo.qty)
    expect(initialMargin * BigInt(10 - 1)).to.equals(positionInfo.holdPoolAmount)
    expect(-tradeFee * BigInt(25000)).to.equals(positionInfo.realizedPnl)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(btcUsd, oracles.format(oracle))
    expect(initialMargin * BigInt(10) * BigInt(25000)).to.equals(marketInfo.longPositionInterest)
  })

})
