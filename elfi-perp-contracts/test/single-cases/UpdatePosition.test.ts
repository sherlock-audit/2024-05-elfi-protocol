import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { ORDER_ID_KEY, OrderSide, OrderType, PositionSide, StopType } from '@utils/constants'
import { precision } from '@utils/precision'
import { AccountFacet, FeeFacet, MarketFacet, MockToken, OrderFacet, PoolFacet, PositionFacet, TradeVault } from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'
import { createOrder, handleOrder } from '@utils/order'
import { handleMint } from '@utils/mint'
import { account } from '@utils/account'
import { handleUpdateLeverage, handleUpdateMargin } from '@utils/position'
import { pool } from '@utils/pool'
import { deposit } from '@utils/deposit'

describe('Update Position', function () {
  let fixture: Fixture
  let tradeVault: TradeVault,
    marketFacet: MarketFacet,
    orderFacet: OrderFacet,
    poolFacet: PoolFacet,
    accountFacet: AccountFacet,
    positionFacet: PositionFacet,
    feeFacet: FeeFacet
  let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner
  let diamondAddr: string,
    tradeVaultAddr: string,
    wbtcAddr: string,
    wethAddr: string,
    usdcAddr: string
  let btcUsd: string, ethUsd: string, xBtc: string, xEth: string, xUsd: string
  let wbtc: MockToken, weth: MockToken, usdc: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ tradeVault, marketFacet, poolFacet, orderFacet, accountFacet, positionFacet, feeFacet } = fixture.contracts)
    ;({ user0, user1, user2 } = fixture.accounts)
    ;({ btcUsd, ethUsd } = fixture.symbols)
    ;({ xBtc, xEth, xUsd } = fixture.pools)
    ;({ wbtc, weth, usdc } = fixture.tokens)
    ;({ diamondAddr, tradeVaultAddr } = fixture.addresses)
    wbtcAddr = await wbtc.getAddress()
    wethAddr = await weth.getAddress()
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

  it('Case1: Update Margin With Position Long', async function () {
    const orderMargin1 = precision.token(1, 17) // 0.1ETH
    const ethPrice0 = precision.price(1800)
    const ethOracle0 = [{ token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 }]

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      oracle: ethOracle0,
      leverage: precision.rate(9),
    })

    const defaultMarginMode = false
    const position0 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    const tokenBalance0 = BigInt(await weth.balanceOf(user0.address))
    const marketBalance0 = BigInt(await weth.balanceOf(xEth))
    const poolInfo0 = await poolFacet.getPool(xEth)
    const accountInfo0 = await accountFacet.getAccountInfo(user0.address)

    // add margin
    const ethPrice1 = precision.price(1789)
    const ethOracle1 = [{ token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 }]
    const addMargin = precision.token(3, 16) //0.03ETH
    const executionFee = precision.token(2, 15)
    await handleUpdateMargin(fixture, {
      positionKey: position0.key,
      isAdd: true,
      marginToken: weth,
      updateMarginAmount: addMargin,
      oracle: ethOracle1,
      executionFee: executionFee,
      isCrossMargin: defaultMarginMode,
    })

    const position1 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    const tokenBalance1 = BigInt(await weth.balanceOf(user0.address))
    const marketBalance1 = BigInt(await weth.balanceOf(xEth))
    const poolInfo1 = await poolFacet.getPool(xEth)
    const accountInfo1 = await accountFacet.getAccountInfo(user0.address)

    // vault & wallet
    expect(-addMargin).to.equals(tokenBalance1 - tokenBalance0)
    expect(addMargin).to.equals(marketBalance1 - marketBalance0)

    // position
    expect(position0.qty).to.equals(position1.qty)
    expect(position0.entryPrice).to.equals(position1.entryPrice)
    expect(addMargin).to.equals(position1.initialMargin - position0.initialMargin)
    expect(precision.mulPrice(addMargin, ethPrice1)).to.equals(
      position1.initialMarginInUsd - position0.initialMarginInUsd,
    )
    expect(precision.mulPrice(addMargin, ethPrice1)).to.equals(
      position1.initialMarginInUsdFromBalance - position0.initialMarginInUsdFromBalance,
    )
    expect(-addMargin).to.equals(position1.holdPoolAmount - position0.holdPoolAmount)
    expect(
      (position0.qty * BigInt(10 ** 5)) / (position0.initialMarginInUsd + precision.mulPrice(addMargin, ethPrice1)),
    ).to.equals(position1.leverage)

    // pool
    expect(-addMargin).to.equals(poolInfo1.baseTokenBalance.holdAmount - poolInfo0.baseTokenBalance.holdAmount)

    // place new limit order
    const orderMargin2 = precision.token(1, 17) // 0.1ETH
    await createOrder(fixture, {
      orderType: OrderType.LIMIT,
      orderMargin: orderMargin2,
      leverage: position1.leverage,
      triggerPrice: precision.price(1750),
    })
    const orderId2 = await marketFacet.getLastUuid(ORDER_ID_KEY)

    const orders0 = await orderFacet.getAccountOrders(user0.address)
    expect(position1.leverage).to.equals(orders0[0].orderInfo.leverage)

    // decrease margin
    const ethPrice2 = precision.price(1792)
    const ethOracle2 = [{ token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 }]
    const reduceMargin = precision.token(2, 16) //0.02ETH
    await handleUpdateMargin(fixture, {
      positionKey: position0.key,
      isAdd: false,
      marginToken: weth,
      updateMarginAmount: precision.mulPrice(reduceMargin, ethPrice2),
      oracle: ethOracle2,
      executionFee: executionFee,
      isCrossMargin: defaultMarginMode,
    })

    const position2 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    const tokenBalance2 = BigInt(await weth.balanceOf(user0.address))
    const marketBalance2 = BigInt(await weth.balanceOf(xEth))
    const poolInfo2 = await poolFacet.getPool(xEth)
    const accountInfo2 = await accountFacet.getAccountInfo(user0.address)

    // vault & wallet
    expect(reduceMargin - orderMargin2).to.equals(tokenBalance2 - tokenBalance1)
    expect(-reduceMargin).to.equals(marketBalance2 - marketBalance1)

    // position
    expect(position1.qty).to.equals(position2.qty)
    expect(position1.entryPrice).to.equals(position2.entryPrice)
    expect(-reduceMargin).to.equals(position2.initialMargin - position1.initialMargin)
    expect(-precision.mulPrice(reduceMargin, ethPrice2)).to.equals(
      position2.initialMarginInUsd - position1.initialMarginInUsd,
    )
    expect(-precision.mulPrice(reduceMargin, ethPrice2)).to.equals(
      position2.initialMarginInUsdFromBalance - position1.initialMarginInUsdFromBalance,
    )
    expect(reduceMargin).to.equals(position2.holdPoolAmount - position1.holdPoolAmount)
    expect(
      (position1.qty * BigInt(10 ** 5)) / (position1.initialMarginInUsd - precision.mulPrice(reduceMargin, ethPrice2)),
    ).to.equals(position2.leverage)

    // pool
    expect(reduceMargin).to.equals(poolInfo2.baseTokenBalance.holdAmount - poolInfo1.baseTokenBalance.holdAmount)

    // orders
    const orders1 = await orderFacet.getAccountOrders(user0.address)
    expect(position2.leverage).to.equals(orders1[0].orderInfo.leverage)
  })

  it('Case2: Update Margin With Position Short', async function () {
    const orderMargin1 = precision.token(999, 6) // 999 USDC
    const ethPrice0 = precision.price(1800)
    const usdcPrice0 = precision.price(99, 6)
    const oracle0 = [
      { token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 },
      { token: usdcAddr, minPrice: usdcPrice0, maxPrice: usdcPrice0 },
    ]

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      oracle: oracle0,
      leverage: precision.rate(8),
    })

    const defaultMarginMode = false
    const position0 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    const tokenBalance0 = BigInt(await usdc.balanceOf(user0.address))
    const marketBalance0 = BigInt(await usdc.balanceOf(xEth))
    const poolInfo0 = await poolFacet.getUsdPool()
    const accountInfo0 = await accountFacet.getAccountInfo(user0.address)

    // add margin
    const ethPrice1 = precision.price(1803)
    const usdcPrice1 = precision.price(999, 5)
    const oracle1 = [
      { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
      { token: usdcAddr, minPrice: usdcPrice1, maxPrice: usdcPrice1 },
    ]
    const addMargin = precision.token(99, 6) //99usdc

    await handleUpdateMargin(fixture, {
      positionKey: position0.key,
      isAdd: true,
      marginToken: usdc,
      updateMarginAmount: addMargin,
      oracle: oracle1,
      isCrossMargin: defaultMarginMode,
    })

    const position1 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    const tokenBalance1 = BigInt(await usdc.balanceOf(user0.address))
    const marketBalance1 = BigInt(await usdc.balanceOf(xEth))
    const poolInfo1 = await poolFacet.getUsdPool()
    const accountInfo1 = await accountFacet.getAccountInfo(user0.address)

    // vault & wallet
    expect(-addMargin).to.equals(tokenBalance1 - tokenBalance0)
    expect(addMargin).to.equals(marketBalance1 - marketBalance0)

    // position
    expect(position0.qty).to.equals(position1.qty)
    expect(position0.entryPrice).to.equals(position1.entryPrice)
    expect(addMargin).to.equals(position1.initialMargin - position0.initialMargin)
    expect(precision.mulPrice(addMargin * BigInt(10 ** 12), usdcPrice1)).to.equals(
      position1.initialMarginInUsd - position0.initialMarginInUsd,
    )
    expect(precision.mulPrice(addMargin * BigInt(10 ** 12), usdcPrice1)).to.equals(
      position1.initialMarginInUsdFromBalance - position0.initialMarginInUsdFromBalance,
    )
    expect(-addMargin).to.equals(position1.holdPoolAmount - position0.holdPoolAmount)
    expect(
      (position0.qty * BigInt(10 ** 5)) /
        (position0.initialMarginInUsd + precision.mulPrice(addMargin * BigInt(10 ** 12), usdcPrice1)),
    ).to.equals(position1.leverage)

    // pool
    expect(-addMargin).to.equals(
      pool.getUsdPoolStableTokenHoldAmount(poolInfo1, usdcAddr) -
        pool.getUsdPoolStableTokenHoldAmount(poolInfo0, usdcAddr),
    )

    // place new limit order
    const orderMargin2 = precision.token(111, 6) // 111usdc
    await createOrder(fixture, {
      orderType: OrderType.LIMIT,
      orderMargin: orderMargin2,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      leverage: position1.leverage,
      triggerPrice: precision.price(1900),
    })
    const orderId2 = await marketFacet.getLastUuid(ORDER_ID_KEY)

    const orders0 = await orderFacet.getAccountOrders(user0.address)
    expect(position1.leverage).to.equals(orders0[0].orderInfo.leverage)

    // decrease margin
    const ethPrice2 = precision.price(1792)
    const usdcPrice2 = precision.price(1)
    const oracle2 = [
      { token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 },
      { token: usdcAddr, minPrice: usdcPrice2, maxPrice: usdcPrice2 },
    ]
    const reduceMargin = precision.token(99, 6) //99usdc
    await handleUpdateMargin(fixture, {
      positionKey: position0.key,
      isAdd: false,
      marginToken: usdc,
      updateMarginAmount: precision.mulPrice(reduceMargin * BigInt(10 ** 12), usdcPrice2),
      oracle: oracle2,
      isCrossMargin: defaultMarginMode,
    })

    const position2 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    const tokenBalance2 = BigInt(await usdc.balanceOf(user0.address))
    const marketBalance2 = BigInt(await usdc.balanceOf(xEth))
    const poolInfo2 = await poolFacet.getUsdPool()
    const accountInfo2 = await accountFacet.getAccountInfo(user0.address)

    // vault & wallet
    expect(reduceMargin - orderMargin2).to.equals(tokenBalance2 - tokenBalance1)
    expect(-reduceMargin).to.equals(marketBalance2 - marketBalance1)

    // position
    expect(position1.qty).to.equals(position2.qty)
    expect(position1.entryPrice).to.equals(position2.entryPrice)
    expect(-reduceMargin).to.equals(position2.initialMargin - position1.initialMargin)
    expect(-precision.mulPrice(reduceMargin * BigInt(10 ** 12), usdcPrice2)).to.equals(
      position2.initialMarginInUsd - position1.initialMarginInUsd,
    )
    expect(-precision.mulPrice(reduceMargin * BigInt(10 ** 12), usdcPrice2)).to.equals(
      position2.initialMarginInUsdFromBalance - position1.initialMarginInUsdFromBalance,
    )
    expect(reduceMargin).to.equals(position2.holdPoolAmount - position1.holdPoolAmount)
    expect(
      (position1.qty * BigInt(10 ** 5)) /
        (position1.initialMarginInUsd - precision.mulPrice(reduceMargin * BigInt(10 ** 12), usdcPrice2)),
    ).to.equals(position2.leverage)

    // pool
    expect(reduceMargin).to.equals(
      pool.getUsdPoolStableTokenHoldAmount(poolInfo2, usdcAddr) -
        pool.getUsdPoolStableTokenHoldAmount(poolInfo1, usdcAddr),
    )

    // orders
    const orders1 = await orderFacet.getAccountOrders(user0.address)
    expect(position2.leverage).to.equals(orders1[0].orderInfo.leverage)
  })

  it('Case3: Update Leverage With Position Long/Isolate', async function () {
    const orderMargin1 = precision.token(1, 17) // 0.1ETH
    const ethPrice0 = precision.price(1800)
    const ethOracle0 = [{ token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 }]

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      oracle: ethOracle0,
      leverage: precision.rate(9),
    })

    const defaultMarginMode = false
    const position0 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    const tokenBalance0 = BigInt(await weth.balanceOf(user0.address))
    const marketBalance0 = BigInt(await weth.balanceOf(xEth))
    const poolInfo0 = await poolFacet.getPool(xEth)
    const accountInfo0 = await accountFacet.getAccountInfo(user0.address)

    // leverage down
    const ethPrice1 = precision.price(1789)
    const ethOracle1 = [{ token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 }]
    const addMargin = precision.token(3, 16) //0.03ETH
    const executionFee = precision.token(2, 15)
    await handleUpdateLeverage(fixture, {
      symbol: ethUsd,
      isLong: true,
      isCrossMargin: defaultMarginMode,
      leverage: precision.rate(8), // not used
      addMarginAmount: addMargin,
      marginToken: weth,
      oracle: ethOracle1,
      executionFee: executionFee,
    })

    const position1 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    const tokenBalance1 = BigInt(await weth.balanceOf(user0.address))
    const marketBalance1 = BigInt(await weth.balanceOf(xEth))
    const poolInfo1 = await poolFacet.getPool(xEth)
    const accountInfo1 = await accountFacet.getAccountInfo(user0.address)

    // vault & wallet
    expect(-addMargin).to.equals(tokenBalance1 - tokenBalance0)
    expect(addMargin).to.equals(marketBalance1 - marketBalance0)

    // position
    expect(position0.qty).to.equals(position1.qty)
    expect(position0.entryPrice).to.equals(position1.entryPrice)
    expect(addMargin).to.equals(position1.initialMargin - position0.initialMargin)
    expect(precision.mulPrice(addMargin, ethPrice1)).to.equals(
      position1.initialMarginInUsd - position0.initialMarginInUsd,
    )
    expect(precision.mulPrice(addMargin, ethPrice1)).to.equals(
      position1.initialMarginInUsdFromBalance - position0.initialMarginInUsdFromBalance,
    )
    expect(-addMargin).to.equals(position1.holdPoolAmount - position0.holdPoolAmount)
    expect(
      (position0.qty * BigInt(10 ** 5)) / (position0.initialMarginInUsd + precision.mulPrice(addMargin, ethPrice1)),
    ).to.equals(position1.leverage)

    // pool
    expect(-addMargin).to.equals(poolInfo1.baseTokenBalance.holdAmount - poolInfo0.baseTokenBalance.holdAmount)

    // place new limit order
    const orderMargin2 = precision.token(1, 17) // 0.1ETH
    await createOrder(fixture, {
      orderType: OrderType.LIMIT,
      orderMargin: orderMargin2,
      leverage: position1.leverage,
      triggerPrice: precision.price(1750),
    })
    const orderId2 = await marketFacet.getLastUuid(ORDER_ID_KEY)

    const orders0 = await orderFacet.getAccountOrders(user0.address)
    expect(position1.leverage).to.equals(orders0[0].orderInfo.leverage)

    // leverage up
    const ethPrice2 = precision.price(1792)
    const ethOracle2 = [{ token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 }]

    const newLeverage = precision.rate(11)
    await handleUpdateLeverage(fixture, {
      symbol: ethUsd,
      isLong: true,
      isCrossMargin: defaultMarginMode,
      leverage: newLeverage,
      addMarginAmount: 0,
      marginToken: weth,
      oracle: ethOracle2,
      executionFee: executionFee,
    })

    const position2 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    const tokenBalance2 = BigInt(await weth.balanceOf(user0.address))
    const marketBalance2 = BigInt(await weth.balanceOf(xEth))
    const poolInfo2 = await poolFacet.getPool(xEth)
    const accountInfo2 = await accountFacet.getAccountInfo(user0.address)

    const reduceMargin = precision.divPrice(
      position1.initialMarginInUsd - precision.divRate(position1.qty, newLeverage),
      ethPrice2,
    )

    // vault & wallet
    expect(reduceMargin - orderMargin2).to.equals(tokenBalance2 - tokenBalance1)
    expect(-reduceMargin).to.equals(marketBalance2 - marketBalance1)

    // position
    expect(position1.qty).to.equals(position2.qty)
    expect(position1.entryPrice).to.equals(position2.entryPrice)
    expect(newLeverage).to.equals(position2.leverage)
    expect(-reduceMargin).to.equals(position2.initialMargin - position1.initialMargin)
    expect(precision.divRate(position2.qty, newLeverage)).to.equals(position2.initialMarginInUsd)
    expect(precision.divRate(position2.qty, newLeverage)).to.equals(position2.initialMarginInUsdFromBalance)
    expect(reduceMargin).to.equals(position2.holdPoolAmount - position1.holdPoolAmount)

    // pool
    expect(reduceMargin).to.equals(poolInfo2.baseTokenBalance.holdAmount - poolInfo1.baseTokenBalance.holdAmount)

    // orders
    const orders1 = await orderFacet.getAccountOrders(user0.address)
    expect(position2.leverage).to.equals(orders1[0].orderInfo.leverage)
  })

  it('Case4: Update Leverage With Position Short/Isolate', async function () {
    const orderMargin1 = precision.token(999, 6) // 999 USDC
    const ethPrice0 = precision.price(1800)
    const usdcPrice0 = precision.price(99, 6)
    const oracle0 = [
      { token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 },
      { token: usdcAddr, minPrice: usdcPrice0, maxPrice: usdcPrice0 },
    ]

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      oracle: oracle0,
      leverage: precision.rate(9),
    })

    const defaultMarginMode = false
    const position0 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    const tokenBalance0 = BigInt(await usdc.balanceOf(user0.address))
    const marketBalance0 = BigInt(await usdc.balanceOf(xEth))
    const poolInfo0 = await poolFacet.getUsdPool()
    const accountInfo0 = await accountFacet.getAccountInfo(user0.address)

    // leverage down
    const ethPrice1 = precision.price(1803)
    const usdcPrice1 = precision.price(999, 5)
    const oracle1 = [
      { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
      { token: usdcAddr, minPrice: usdcPrice1, maxPrice: usdcPrice1 },
    ]
    const addMargin = precision.token(99, 6) //99usdc

    await handleUpdateLeverage(fixture, {
      symbol: ethUsd,
      isLong: false,
      isCrossMargin: defaultMarginMode,
      leverage: precision.rate(8), // not used
      addMarginAmount: addMargin,
      marginToken: usdc,
      oracle: oracle1,
    })

    const position1 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    const tokenBalance1 = BigInt(await usdc.balanceOf(user0.address))
    const marketBalance1 = BigInt(await usdc.balanceOf(xEth))
    const poolInfo1 = await poolFacet.getUsdPool()
    const accountInfo1 = await accountFacet.getAccountInfo(user0.address)

    // vault & wallet
    expect(-addMargin).to.equals(tokenBalance1 - tokenBalance0)
    expect(addMargin).to.equals(marketBalance1 - marketBalance0)

    // position
    expect(position0.qty).to.equals(position1.qty)
    expect(position0.entryPrice).to.equals(position1.entryPrice)
    expect(addMargin).to.equals(position1.initialMargin - position0.initialMargin)
    expect(precision.mulPrice(addMargin * BigInt(10 ** 12), usdcPrice1)).to.equals(
      position1.initialMarginInUsd - position0.initialMarginInUsd,
    )
    expect(precision.mulPrice(addMargin * BigInt(10 ** 12), usdcPrice1)).to.equals(
      position1.initialMarginInUsdFromBalance - position0.initialMarginInUsdFromBalance,
    )
    expect(-addMargin).to.equals(position1.holdPoolAmount - position0.holdPoolAmount)
    expect(
      (position0.qty * BigInt(10 ** 5)) /
        (position0.initialMarginInUsd + precision.mulPrice(addMargin * BigInt(10 ** 12), usdcPrice1)),
    ).to.equals(position1.leverage)

    // pool
    expect(-addMargin).to.equals(
      pool.getUsdPoolStableTokenHoldAmount(poolInfo1, usdcAddr) -
        pool.getUsdPoolStableTokenHoldAmount(poolInfo0, usdcAddr),
    )

    // place new limit order
    const orderMargin2 = precision.token(111, 6) // 111usdc
    await createOrder(fixture, {
      orderType: OrderType.LIMIT,
      orderMargin: orderMargin2,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      leverage: position1.leverage,
      triggerPrice: precision.price(1900),
    })
    const orderId2 = await marketFacet.getLastUuid(ORDER_ID_KEY)

    const orders0 = await orderFacet.getAccountOrders(user0.address)
    expect(position1.leverage).to.equals(orders0[0].orderInfo.leverage)

    // leverage up
    const ethPrice2 = precision.price(1792)
    const usdcPrice2 = precision.price(1)
    const oracle2 = [
      { token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 },
      { token: usdcAddr, minPrice: usdcPrice2, maxPrice: usdcPrice2 },
    ]

    const newLeverage = precision.rate(11)
    await handleUpdateLeverage(fixture, {
      symbol: ethUsd,
      isLong: false,
      isCrossMargin: defaultMarginMode,
      leverage: newLeverage,
      addMarginAmount: 0,
      marginToken: usdc,
      oracle: oracle2,
    })

    const position2 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    const tokenBalance2 = BigInt(await usdc.balanceOf(user0.address))
    const marketBalance2 = BigInt(await usdc.balanceOf(xEth))
    const poolInfo2 = await poolFacet.getUsdPool()
    const accountInfo2 = await accountFacet.getAccountInfo(user0.address)

    const reduceMargin =
      precision.divPrice(position1.initialMarginInUsd - precision.divRate(position1.qty, newLeverage), usdcPrice2) /
      BigInt(10 ** 12)

    // vault & wallet
    expect(reduceMargin - orderMargin2).to.equals(tokenBalance2 - tokenBalance1)
    expect(-reduceMargin).to.equals(marketBalance2 - marketBalance1)

    // position
    expect(position1.qty).to.equals(position2.qty)
    expect(position1.entryPrice).to.equals(position2.entryPrice)
    expect(newLeverage).to.equals(position2.leverage)
    expect(-reduceMargin).to.equals(position2.initialMargin - position1.initialMargin)
    expect(precision.divRate(position2.qty, newLeverage)).to.equals(position2.initialMarginInUsd)
    expect(precision.divRate(position2.qty, newLeverage)).to.equals(position2.initialMarginInUsdFromBalance)
    expect(reduceMargin).to.equals(position2.holdPoolAmount - position1.holdPoolAmount)

    // pool
    expect(reduceMargin).to.equals(
      pool.getUsdPoolStableTokenHoldAmount(poolInfo2, usdcAddr) -
        pool.getUsdPoolStableTokenHoldAmount(poolInfo1, usdcAddr),
    )

    // orders
    const orders1 = await orderFacet.getAccountOrders(user0.address)
    expect(position2.leverage).to.equals(orders1[0].orderInfo.leverage)
  })

  it('Case5: Update Leverage With CrossMargin', async function () {
    const usdcAmount = precision.token(2000, 6) //2000 USDC
    await deposit(fixture, {
      account: user0,
      token: usdc,
      amount: usdcAmount,
    })

    // const ethAmount = precision.token(2, 17) //0.2 weth
    // await deposit(fixture, {
    //   account: user0,
    //   token: weth,
    //   amount: ethAmount,
    // })

    const orderMarginInUsd0 = precision.token(999) // 999$
    const ethPrice0 = precision.price(1800)
    const usdcPrice0 = precision.price(1)
    const oracle0 = [
      { token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 },
      { token: usdcAddr, minPrice: usdcPrice0, maxPrice: usdcPrice0 },
    ]

    await handleOrder(fixture, {
      orderMargin: orderMarginInUsd0,
      oracle: oracle0,
      isCrossMargin: true,
      marginToken: weth,
      leverage: precision.rate(9),
    })

    const position0 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, true)
    const poolInfo0 = await poolFacet.getPool(xEth)
    const accountInfo0 = await accountFacet.getAccountInfo(user0.address)

    // leverage down
    const ethPrice1 = precision.price(1780)
    const usdcPrice1 = precision.price(99, 6)
    const oracle1 = [
      { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
      { token: usdcAddr, minPrice: usdcPrice1, maxPrice: usdcPrice1 },
    ]
    const executionFee = precision.token(2, 15)

    const leverage1 = precision.rate(8)
    await handleUpdateLeverage(fixture, {
      symbol: ethUsd,
      isLong: true,
      isCrossMargin: true,
      leverage: leverage1,
      addMarginAmount: 0,
      marginToken: weth,
      oracle: oracle1,
      executionFee: executionFee,
    })

    const position1 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, true)
    const poolInfo1 = await poolFacet.getPool(xEth)
    const accountInfo1 = await accountFacet.getAccountInfo(user0.address)
    const addMargin = precision.divPrice(
      precision.divRate(position1.qty, leverage1) - position0.initialMarginInUsd,
      ethPrice1,
    )

    // position
    expect(position0.qty).to.equals(position1.qty)
    expect(position0.entryPrice).to.equals(position1.entryPrice)
    expect(addMargin).to.equals(position1.initialMargin - position0.initialMargin)
    expect(precision.divRate(position1.qty, leverage1)).to.equals(position1.initialMarginInUsd)
    expect(0).to.equals(position1.initialMarginInUsdFromBalance - position0.initialMarginInUsdFromBalance)
    expect(-addMargin).to.equals(position1.holdPoolAmount - position0.holdPoolAmount)
    expect(leverage1).to.equals(position1.leverage)

    // account
    expect(addMargin).to.equals(
      account.getAccountTokenUsedAmount(accountInfo1, wethAddr) -
        account.getAccountTokenUsedAmount(accountInfo0, wethAddr),
    )

    // pool
    expect(-addMargin).to.equals(poolInfo1.baseTokenBalance.holdAmount - poolInfo0.baseTokenBalance.holdAmount)

    // place new limit order
    const orderMargin2 = precision.token(50)
    await createOrder(fixture, {
      orderType: OrderType.LIMIT,
      orderMargin: orderMargin2,
      isCrossMargin: true,
      leverage: leverage1,
      triggerPrice: precision.price(1750),
      executionFee: executionFee,
    })
    const orderId2 = await marketFacet.getLastUuid(ORDER_ID_KEY)

    const orders0 = await orderFacet.getAccountOrders(user0.address)
    expect(position1.leverage).to.equals(orders0[0].orderInfo.leverage)

    // leverage up
    const ethPrice2 = precision.price(1792)
    const usdcPrice2 = precision.price(99, 6)
    const oracle2 = [
      { token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 },
      { token: usdcAddr, minPrice: usdcPrice2, maxPrice: usdcPrice2 },
    ]

    const leverage2 = precision.rate(11)
    await handleUpdateLeverage(fixture, {
      symbol: ethUsd,
      isLong: true,
      isCrossMargin: true,
      leverage: leverage2,
      addMarginAmount: 0,
      marginToken: weth,
      oracle: oracle2,
      executionFee: executionFee,
    })

    const position2 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, true)
    const poolInfo2 = await poolFacet.getPool(xEth)
    const accountInfo2 = await accountFacet.getAccountInfo(user0.address)

    const reduceMargin = precision.divPrice(
      position1.initialMarginInUsd - precision.divRate(position1.qty, leverage2),
      ethPrice2,
    )

    // position
    expect(position1.qty).to.equals(position2.qty)
    expect(position1.entryPrice).to.equals(position2.entryPrice)
    expect(leverage2).to.equals(position2.leverage)
    expect(-reduceMargin).to.equals(position2.initialMargin - position1.initialMargin)
    expect(precision.divRate(position2.qty, leverage2)).to.equals(position2.initialMarginInUsd)
    expect(reduceMargin).to.equals(position2.holdPoolAmount - position1.holdPoolAmount)

    // account
    expect(-reduceMargin).to.equals(
      account.getAccountTokenUsedAmount(accountInfo2, wethAddr) -
        account.getAccountTokenUsedAmount(accountInfo1, wethAddr),
    )

    // pool
    expect(reduceMargin).to.equals(poolInfo2.baseTokenBalance.holdAmount - poolInfo1.baseTokenBalance.holdAmount)

    // orders
    const orders1 = await orderFacet.getAccountOrders(user0.address)
    expect(leverage2).to.equals(orders1[0].orderInfo.leverage)
  })
})
