import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { ORDER_ID_KEY, OrderSide, OrderType, PositionSide, StopType } from '@utils/constants'
import { precision } from '@utils/precision'
import {
  AccountFacet,
  FeeFacet,
  MarketFacet,
  MockToken,
  OrderFacet,
  ConfigFacet,
  PoolFacet,
  PositionFacet,
  TradeVault,
} from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'
import { handleOrder } from '@utils/order'
import { handleMint } from '@utils/mint'
import { account } from '@utils/account'
import { pool } from '@utils/pool'
import { oracles } from '@utils/oracles'

describe('Increase Market Order Process', function () {
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
    tradeVaultAddr: string,
    wbtcAddr: string,
    wethAddr: string,
    solAddr: string,
    usdcAddr: string
  let btcUsd: string, ethUsd: string, solUsd: string, xBtc: string, xEth: string, xUsd: string
  let wbtc: MockToken, weth: MockToken, sol: MockToken, usdc: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ tradeVault, marketFacet, poolFacet, orderFacet, configFacet, accountFacet, positionFacet, feeFacet } =
      fixture.contracts)
    ;({ user0, user1, user2, user3 } = fixture.accounts)
    ;({ btcUsd, ethUsd, solUsd } = fixture.symbols)
    ;({ xBtc, xEth, xUsd } = fixture.pools)
    ;({ wbtc, weth, sol, usdc } = fixture.tokens)
    ;({ diamondAddr, tradeVaultAddr } = fixture.addresses)
    wbtcAddr = await wbtc.getAddress()
    wethAddr = await weth.getAddress()
    solAddr = await sol.getAddress()
    usdcAddr = await usdc.getAddress()

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
      requestTokenAmount: precision.token(500),
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

  it('Case1: Place Single Market Order Single User/Once/Long', async function () {
    const preTokenBalance = BigInt(await wbtc.balanceOf(user0.address))
    const preVaultBalance = BigInt(await wbtc.balanceOf(tradeVaultAddr))
    const preMarketBalance = BigInt(await wbtc.balanceOf(xBtc))
    // const preTotalFee = await feeFacet.getTokenFee(xBtc, wbtcAddr)

    const orderMargin = precision.token(1, 17) // 0.1BTC

    const executionFee = precision.token(2, 15)

    wbtc.connect(user0).approve(diamondAddr, orderMargin)

    const tx = await orderFacet.connect(user0).createOrderRequest(
      {
        symbol: btcUsd,
        orderSide: OrderSide.LONG,
        posSide: PositionSide.INCREASE,
        orderType: OrderType.MARKET,
        stopType: StopType.NONE,
        isCrossMargin: false,
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

    const nextTokenBalance = BigInt(await wbtc.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await wbtc.balanceOf(tradeVaultAddr))

    // vault & user token amount
    expect(orderMargin).to.equals(nextVaultBalance - preVaultBalance)
    expect(orderMargin).to.equals(preTokenBalance - nextTokenBalance)

    // Account
    const accountInfo = await accountFacet.getAccountInfo(user0.address)
    expect(user0.address).to.equals(accountInfo.owner)
    expect(0).to.equals(account.getAccountTokenAmount(accountInfo, wbtcAddr))
    expect(0).to.equals(account.getAccountTokenUsedAmount(accountInfo, wbtcAddr))

    // Order
    const orders = await orderFacet.getAccountOrders(user0.address)
    expect(1).to.equals(orders.length)
    expect(user0.address).to.equals(orders[0].orderInfo.account)
    expect(false).to.equals(orders[0].orderInfo.isCrossMargin)
    expect(OrderType.MARKET).to.equals(orders[0].orderInfo.orderType)
    expect(btcUsd).to.equals(orders[0].orderInfo.symbol)
    expect(wbtcAddr).to.equals(orders[0].orderInfo.marginToken)

    const requestId = await marketFacet.getLastUuid(ORDER_ID_KEY)

    const tokenPrice = precision.price(25000)
    const oracle = [{ token: wbtcAddr, targetToken: ethers.ZeroAddress, minPrice: tokenPrice, maxPrice: tokenPrice }]

    await orderFacet.connect(user3).executeOrder(requestId, oracle)

    const symbolInfo = await marketFacet.getSymbol(btcUsd)
    const nextVaultBalance1 = BigInt(await wbtc.balanceOf(tradeVaultAddr))
    const nextMarketBalance = BigInt(await wbtc.balanceOf(xBtc))
    const leverageMargin = precision.mulRate(orderMargin, precision.rate(10))
    const tradeFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = orderMargin - tradeFee

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance1 - preVaultBalance)
    expect(orderMargin).to.equals(nextMarketBalance - preMarketBalance)

    // pool
    const poolInfo = await poolFacet.getPool(xBtc)
    expect(initialMargin * BigInt(10 - 1)).to.equals(poolInfo.baseTokenBalance.holdAmount)
    expect(0).to.equals(poolInfo.borrowingFee.cumulativeBorrowingFeePerToken)
    expect(0).to.equals(poolInfo.borrowingFee.totalBorrowingFee)
    expect(0).to.equals(poolInfo.borrowingFee.totalRealizedBorrowingFee)

    // Account
    const accountInfo2 = await accountFacet.getAccountInfo(user0.address)
    expect(1).to.equals(accountInfo2.positions.length)

    // Position
    const positionInfo = await positionFacet.getSinglePosition(user0.address, btcUsd, wbtcAddr, false)
    expect(initialMargin).to.equals(positionInfo.initialMargin)
    expect(initialMargin * BigInt(25000)).to.equals(positionInfo.initialMarginInUsd)
    expect(initialMargin * BigInt(25000)).to.equals(positionInfo.initialMarginInUsdFromBalance)
    expect(precision.rate(10)).to.equals(positionInfo.leverage)
    expect(tokenPrice).to.equals(positionInfo.entryPrice)
    expect(btcUsd).to.equals(positionInfo.symbol)
    expect(wbtcAddr).to.equals(positionInfo.marginToken)
    expect(symbolInfo.indexToken).to.equals(positionInfo.indexToken)
    expect(true).to.equals(positionInfo.isLong)
    expect(initialMargin * BigInt(10) * BigInt(25000)).to.equals(positionInfo.qty)
    expect(initialMargin * BigInt(10 - 1)).to.equals(positionInfo.holdPoolAmount)
    expect(-tradeFee * BigInt(25000)).to.equals(positionInfo.realizedPnl)
    expect(0).to.equals(positionInfo.positionFee.openBorrowingFeePerToken)
    expect(0).to.equals(positionInfo.positionFee.openFundingFeePerQty)
    expect(0).to.equals(positionInfo.positionFee.realizedBorrowingFee)
    expect(0).to.equals(positionInfo.positionFee.realizedBorrowingFeeInUsd)
    expect(0).to.equals(positionInfo.positionFee.realizedFundingFee)
    expect(0).to.equals(positionInfo.positionFee.realizedBorrowingFeeInUsd)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(btcUsd, oracles.format(oracle))
    expect(initialMargin * BigInt(10) * BigInt(25000)).to.equals(marketInfo.longPositionInterest)
    expect(0).to.equals(marketInfo.fundingFee.longFundingFeePerQty)
    expect(0).to.equals(marketInfo.fundingFee.shortFundingFeePerQty)
    expect(0).to.equals(marketInfo.fundingFee.totalLongFundingFee)
    expect(0).to.equals(marketInfo.fundingFee.totalShortFundingFee)
  })

  it('Case2: Place Market Order Single User/Multi place order/Long', async function () {
    const preTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const preVaultBalance = BigInt(await weth.balanceOf(tradeVaultAddr))
    const preMarketBalance = BigInt(await weth.balanceOf(xEth))

    const orderMargin1 = precision.token(1, 17) // 0.1ETH
    const ethPrice1 = precision.price(1800)
    const ethOracle1 = [{ token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 }]
    const executionFee = precision.token(2, 15)

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      oracle: ethOracle1,
      executionFee: executionFee,
    })

    const orderMargin2 = precision.token(12, 17) // 1.2ETH

    await handleOrder(fixture, {
      orderMargin: orderMargin2,
      oracle: ethOracle1,
      executionFee: executionFee,
    })

    const orderMargin3 = precision.token(3, 17) // 0.3ETH
    await handleOrder(fixture, {
      orderMargin: orderMargin3,
      oracle: ethOracle1,
      executionFee: executionFee,
    })

    const nextTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await weth.balanceOf(tradeVaultAddr))
    const nextMarketBalance = BigInt(await weth.balanceOf(xEth))
    const totalMargin = orderMargin1 + orderMargin2 + orderMargin3

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(totalMargin).to.equals(nextMarketBalance - preMarketBalance)
    expect(totalMargin).to.equals(preTokenBalance - nextTokenBalance)

    // Fee
    const symbolInfo = await marketFacet.getSymbol(ethUsd)
    const leverageMargin = precision.mulRate(totalMargin, precision.rate(10))
    const tradeFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = totalMargin - tradeFee

    // Account
    const accountInfo = await accountFacet.getAccountInfo(user0.address)
    expect(user0.address).to.equals(accountInfo.owner)

    // pool
    const poolInfo = await poolFacet.getPool(xEth)
    expect(initialMargin * BigInt(10 - 1)).to.equals(poolInfo.baseTokenBalance.holdAmount)

    // Position
    const defaultMarginMode = false
    const positionInfo = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(initialMargin).to.equals(positionInfo.initialMargin)
    expect(initialMargin * BigInt(1800)).to.equals(positionInfo.initialMarginInUsd)
    expect(initialMargin * BigInt(1800)).to.equals(positionInfo.initialMarginInUsdFromBalance)
    expect(precision.rate(10)).to.equals(positionInfo.leverage)
    expect(ethPrice1).to.equals(positionInfo.entryPrice)
    expect(ethUsd).to.equals(positionInfo.symbol)
    expect(wethAddr).to.equals(positionInfo.marginToken)
    expect(symbolInfo.indexToken).to.equals(positionInfo.indexToken)
    expect(true).to.equals(positionInfo.isLong)
    expect(initialMargin * BigInt(10) * BigInt(1800)).to.equals(positionInfo.qty)
    expect(initialMargin * BigInt(10 - 1)).to.equals(positionInfo.holdPoolAmount)
    expect(-tradeFee * BigInt(1800)).to.equals(positionInfo.realizedPnl)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(ethUsd, oracles.format(ethOracle1))
    expect(initialMargin * BigInt(10) * BigInt(1800)).to.equals(marketInfo.longPositionInterest)
  })

  it('Case3: Place Single Market Order Single User/Multi place order/Multi Price/Long', async function () {
    const preTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const preVaultBalance = BigInt(await weth.balanceOf(tradeVaultAddr))
    const preMarketBalance = BigInt(await weth.balanceOf(xEth))

    const orderMargin1 = precision.token(1, 17) // 0.1eth
    const ethPrice1 = precision.price(1800)
    const ethOracle1 = [{ token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 }]
    const executionFee = precision.token(2, 15)

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      oracle: ethOracle1,
      executionFee: executionFee,
    })

    const orderMargin2 = precision.token(12, 17) // 1.2eth
    const ethPrice2 = precision.price(1850)
    const ethOracle2 = [{ token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 }]

    await handleOrder(fixture, {
      orderMargin: orderMargin2,
      oracle: ethOracle2,
      executionFee: executionFee,
    })

    const orderMargin3 = precision.token(3, 17) // 0.3eth
    const ethPrice3 = precision.price(1810)
    const ethOracle3 = [{ token: wethAddr, minPrice: ethPrice3, maxPrice: ethPrice3 }]

    await handleOrder(fixture, {
      orderMargin: orderMargin3,
      oracle: ethOracle3,
      executionFee: executionFee,
    })

    const nextTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await weth.balanceOf(tradeVaultAddr))
    const nextMarketBalance = BigInt(await weth.balanceOf(xEth))
    const totalMargin = orderMargin1 + orderMargin2 + orderMargin3

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(totalMargin).to.equals(nextMarketBalance - preMarketBalance)
    expect(totalMargin).to.equals(preTokenBalance - nextTokenBalance)

    // Fee
    const symbolInfo = await marketFacet.getSymbol(ethUsd)
    const leverageMargin = precision.mulRate(totalMargin, precision.rate(10))
    const tradeFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = totalMargin - tradeFee

    // Account
    const accountInfo = await accountFacet.getAccountInfo(user0.address)
    expect(user0.address).to.equals(accountInfo.owner)

    // pool
    const poolInfo = await poolFacet.getPool(xEth)
    expect(initialMargin * BigInt(10 - 1)).to.equals(poolInfo.baseTokenBalance.holdAmount)

    // Position
    const leverageMargin1 = precision.mulRate(orderMargin1, precision.rate(10))
    const tradeFee1 = precision.mulRate(leverageMargin1, symbolInfo.config.openFeeRate)
    const leverageMargin2 = precision.mulRate(orderMargin2, precision.rate(10))
    const tradeFee2 = precision.mulRate(leverageMargin2, symbolInfo.config.openFeeRate)
    const leverageMargin3 = precision.mulRate(orderMargin3, precision.rate(10))
    const tradeFee3 = precision.mulRate(leverageMargin3, symbolInfo.config.openFeeRate)

    const defaultMarginMode = false
    const positionInfo = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(initialMargin).to.equals(positionInfo.initialMargin)
    expect(
      precision.mulPrice(orderMargin1 - tradeFee1, ethPrice1) +
        precision.mulPrice(orderMargin2 - tradeFee2, ethPrice2) +
        precision.mulPrice(orderMargin3 - tradeFee3, ethPrice3),
    ).to.equals(positionInfo.initialMarginInUsd)
    expect(positionInfo.initialMarginInUsd).to.equals(positionInfo.initialMarginInUsdFromBalance)
    expect(precision.rate(10)).to.equals(positionInfo.leverage)

    const originEntryPrice1 =
      (ethPrice1 * precision.mulPrice(BigInt(10) * (orderMargin1 - tradeFee1), ethPrice1) +
        ethPrice2 * precision.mulPrice(BigInt(10) * (orderMargin2 - tradeFee2), ethPrice2)) /
      (precision.mulPrice(BigInt(10) * (orderMargin1 - tradeFee1), ethPrice1) +
        precision.mulPrice(BigInt(10) * (orderMargin2 - tradeFee2), ethPrice2))
    var entryPrice1
    if (originEntryPrice1 % symbolInfo.config.tickSize == BigInt(0)) {
      entryPrice1 = originEntryPrice1
    } else {
      entryPrice1 = (originEntryPrice1 / symbolInfo.config.tickSize + BigInt(1)) * symbolInfo.config.tickSize
    }

    const originEntryPrice2 =
      (entryPrice1 *
        (precision.mulPrice(BigInt(10) * (orderMargin1 - tradeFee1), ethPrice1) +
          precision.mulPrice(BigInt(10) * (orderMargin2 - tradeFee2), ethPrice2)) +
        ethPrice3 * precision.mulPrice(BigInt(10) * (orderMargin3 - tradeFee3), ethPrice3)) /
      positionInfo.qty
    var entryPrice
    if (originEntryPrice2 % symbolInfo.config.tickSize == BigInt(0)) {
      entryPrice = originEntryPrice2
    } else {
      entryPrice = (originEntryPrice2 / symbolInfo.config.tickSize + BigInt(1)) * symbolInfo.config.tickSize
    }

    expect(entryPrice).to.equals(positionInfo.entryPrice)
    expect(ethUsd).to.equals(positionInfo.symbol)
    expect(wethAddr).to.equals(positionInfo.marginToken)
    expect(symbolInfo.indexToken).to.equals(positionInfo.indexToken)
    expect(true).to.equals(positionInfo.isLong)
    expect(positionInfo.initialMarginInUsd * BigInt(10)).to.equals(positionInfo.qty)
    expect(initialMargin * BigInt(10 - 1)).to.equals(positionInfo.holdPoolAmount)
    expect(
      -(
        precision.mulPrice(tradeFee1, ethPrice1) +
        precision.mulPrice(tradeFee2, ethPrice2) +
        precision.mulPrice(tradeFee3, ethPrice3)
      ),
    ).to.equals(positionInfo.realizedPnl)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(ethUsd, oracles.format(ethOracle3))
    expect(positionInfo.initialMarginInUsd * BigInt(10)).to.equals(marketInfo.longPositionInterest)
  })

  it('Case4: Place Single Market Order Single User/Single Price/Short/USDT', async function () {
    const preTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const preVaultBalance = BigInt(await usdc.balanceOf(tradeVaultAddr))
    const preMarketBalance = BigInt(await usdc.balanceOf(xEth))
    const preAccountInfo = await accountFacet.getAccountInfo(user0.address)

    const orderMargin1 = precision.token(100, 6) // 100USDT
    const ethPrice = precision.price(1800)
    const usdtPrice = precision.price(1)
    const oracle = [
      { token: wethAddr, minPrice: ethPrice, maxPrice: ethPrice },
      { token: usdcAddr, minPrice: usdtPrice, maxPrice: usdtPrice },
    ]

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      oracle: oracle,
    })

    const nextTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await usdc.balanceOf(tradeVaultAddr))
    const nextMarketBalance = BigInt(await usdc.balanceOf(xEth))

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(orderMargin1).to.equals(nextMarketBalance - preMarketBalance)
    expect(orderMargin1).to.equals(preTokenBalance - nextTokenBalance)

    // Fee
    const symbolInfo = await marketFacet.getSymbol(ethUsd)
    const leverageMargin = precision.mulRate(orderMargin1, precision.rate(10))
    const tradeFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = orderMargin1 - tradeFee

    // Account
    const accountInfo = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle))
    expect(user0.address).to.equals(accountInfo.owner)
    expect(0).to.equals(account.getAccountTokenAmount(accountInfo, usdcAddr))
    expect(0).to.equals(account.getAccountTokenUsedAmount(accountInfo, usdcAddr))
    expect(0).to.equals(accountInfo.orderHoldInUsd)
    expect(0).to.equals(accountInfo.portfolioNetValue)
    expect(0).to.equals(accountInfo.totalUsedValue)
    expect(0).to.equals(accountInfo.availableValue)

    // pool
    const poolInfo = await poolFacet.getUsdPool()
    expect(initialMargin * BigInt(10 - 1)).to.equals(poolInfo.stableTokenBalances[0].holdAmount)

    // Position
    const defaultMarginMode = false
    const positionInfo = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(initialMargin).to.equals(positionInfo.initialMargin)
    expect(precision.pow(initialMargin * BigInt(1), 12)).to.equals(positionInfo.initialMarginInUsd)
    expect(precision.pow(initialMargin * BigInt(1), 12)).to.equals(positionInfo.initialMarginInUsdFromBalance)
    expect(precision.rate(10)).to.equals(positionInfo.leverage)
    expect(ethPrice).to.equals(positionInfo.entryPrice)
    expect(ethUsd).to.equals(positionInfo.symbol)
    expect(usdcAddr).to.equals(positionInfo.marginToken)
    expect(symbolInfo.indexToken).to.equals(positionInfo.indexToken)
    expect(false).to.equals(positionInfo.isLong)
    expect(precision.pow(initialMargin * BigInt(10) * BigInt(1), 12)).to.equals(positionInfo.qty)
    expect(initialMargin * BigInt(10 - 1)).to.equals(positionInfo.holdPoolAmount)
    expect(-precision.pow(tradeFee * BigInt(1), 12)).to.equals(positionInfo.realizedPnl)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(ethUsd, oracles.format(oracle))
    expect(precision.pow(initialMargin * BigInt(10) * BigInt(1), 12)).to.equals(marketInfo.totalShortPositionInterest)
  })

  it('Case5:Place Multi order/Multi Price/Short/USDT', async function () {
    const preTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const preVaultBalance = BigInt(await usdc.balanceOf(tradeVaultAddr))
    const preMarketBalance = BigInt(await usdc.balanceOf(xEth))

    const orderMargin1 = precision.token(100, 6) // 100USDT
    const ethPrice1 = precision.price(1800)
    const usdtPrice1 = precision.price(1)
    const oracle1 = [
      { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
      { token: usdcAddr, minPrice: usdtPrice1, maxPrice: usdtPrice1 },
    ]

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      oracle: oracle1,
    })

    const orderMargin2 = precision.token(99, 6) // 99USDT
    const ethPrice2 = precision.price(1805)
    const usdtPrice2 = precision.price(1)
    const oracle2 = [
      { token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 },
      { token: usdcAddr, minPrice: usdtPrice2, maxPrice: usdtPrice2 },
    ]

    await handleOrder(fixture, {
      orderMargin: orderMargin2,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      oracle: oracle2,
    })

    const orderMargin3 = precision.token(88, 6) // 88USDT
    const ethPrice3 = precision.price(1820)
    const usdtPrice3 = precision.price(99, 6)
    const oracle3 = [
      { token: wethAddr, minPrice: ethPrice3, maxPrice: ethPrice3 },
      { token: usdcAddr, minPrice: usdtPrice3, maxPrice: usdtPrice3 },
    ]

    await handleOrder(fixture, {
      orderMargin: orderMargin3,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      oracle: oracle3,
    })

    const nextTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await usdc.balanceOf(tradeVaultAddr))
    const nextMarketBalance = BigInt(await usdc.balanceOf(xEth))

    const totalMargin = orderMargin1 + orderMargin2 + orderMargin3

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(totalMargin).to.equals(nextMarketBalance - preMarketBalance)
    expect(totalMargin).to.equals(preTokenBalance - nextTokenBalance)

    // Fee
    const symbolInfo = await marketFacet.getSymbol(ethUsd)
    const leverageMargin = precision.mulRate(totalMargin, precision.rate(10))
    const tradeFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = totalMargin - tradeFee

    // Account
    const accountInfo = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle3))
    expect(user0.address).to.equals(accountInfo.owner)
    expect(0).to.equals(account.getAccountTokenAmount(accountInfo, usdcAddr))
    expect(0).to.equals(account.getAccountTokenUsedAmount(accountInfo, usdcAddr))

    // pool
    const poolInfo = await poolFacet.getUsdPool()
    expect(initialMargin * BigInt(10 - 1)).to.equals(poolInfo.stableTokenBalances[0].holdAmount)

    // Position
    const defaultMarginMode = false
    const positionInfo = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(initialMargin).to.equals(positionInfo.initialMargin)

    const tradeFee1 = precision.mulRate(
      precision.mulRate(orderMargin1, precision.rate(10)),
      symbolInfo.config.openFeeRate,
    )
    const initialMargin1 = orderMargin1 - tradeFee1
    const tradeFee2 = precision.mulRate(
      precision.mulRate(orderMargin2, precision.rate(10)),
      symbolInfo.config.openFeeRate,
    )
    const initialMargin2 = orderMargin2 - tradeFee2
    const tradeFee3 = precision.mulRate(
      precision.mulRate(orderMargin3, precision.rate(10)),
      symbolInfo.config.openFeeRate,
    )
    const initialMargin3 = orderMargin3 - tradeFee3
    const initialMarginInUsd = initialMargin1 * usdtPrice1 + initialMargin2 * usdtPrice2 + initialMargin3 * usdtPrice3
    expect(precision.pow(initialMarginInUsd, 18 - 6 - 8)).to.equals(positionInfo.initialMarginInUsd)
    expect(precision.pow(initialMarginInUsd, 18 - 6 - 8)).to.equals(positionInfo.initialMarginInUsdFromBalance)

    const qty =
      usdtPrice1 * initialMargin1 * BigInt(10) * BigInt(10 ** 4) +
      usdtPrice2 * initialMargin2 * BigInt(10) * BigInt(10 ** 4) +
      usdtPrice3 * initialMargin3 * BigInt(10) * BigInt(10 ** 4)
    expect(qty).to.equals(positionInfo.qty)

    const originEntryPrice1 =
      (ethPrice1 * precision.mulPrice(initialMargin1 * BigInt(10), usdtPrice1) +
        ethPrice2 * precision.mulPrice(initialMargin2 * BigInt(10), usdtPrice2)) /
      (precision.mulPrice(initialMargin1 * BigInt(10), usdtPrice1) +
        precision.mulPrice(initialMargin2 * BigInt(10), usdtPrice2))
    var entryPrice1
    if (originEntryPrice1 % symbolInfo.config.tickSize == BigInt(0)) {
      entryPrice1 = originEntryPrice1
    } else {
      entryPrice1 = (originEntryPrice1 / symbolInfo.config.tickSize) * symbolInfo.config.tickSize
    }

    const originEntryPrice2 =
      ((entryPrice1 *
        (precision.mulPrice(initialMargin1 * BigInt(10), usdtPrice1) +
          precision.mulPrice(initialMargin2 * BigInt(10), usdtPrice2)) +
        ethPrice3 * precision.mulPrice(initialMargin3 * BigInt(10), usdtPrice3)) *
        BigInt(10 ** 12)) /
      qty
    var entryPrice
    if (originEntryPrice2 % symbolInfo.config.tickSize == BigInt(0)) {
      entryPrice = originEntryPrice2
    } else {
      entryPrice = (originEntryPrice2 / symbolInfo.config.tickSize) * symbolInfo.config.tickSize
    }

    expect(entryPrice).to.equals(positionInfo.entryPrice)
    expect(precision.rate(10)).to.equals(positionInfo.leverage)
    expect(ethUsd).to.equals(positionInfo.symbol)
    expect(usdcAddr).to.equals(positionInfo.marginToken)
    expect(symbolInfo.indexToken).to.equals(positionInfo.indexToken)
    expect(false).to.equals(positionInfo.isLong)
    expect(initialMargin * BigInt(10 - 1)).to.equals(positionInfo.holdPoolAmount)
    expect(-precision.pow(tradeFee1 * usdtPrice1 + tradeFee2 * usdtPrice2 + tradeFee3 * usdtPrice3, 4)).to.equals(
      positionInfo.realizedPnl,
    )

    // Market
    const marketInfo = await marketFacet.getMarketInfo(ethUsd, oracles.format(oracle3))
    expect(qty).to.equals(marketInfo.totalShortPositionInterest)
  })
  
})
