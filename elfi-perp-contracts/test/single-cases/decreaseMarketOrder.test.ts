import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
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
import { Contract } from 'ethers'
import { handleOrder } from '@utils/order'
import { handleMint } from '@utils/mint'
import { OrderSide, PositionSide } from '@utils/constants'
import { account } from '@utils/account'
import { oracles } from '@utils/oracles'

describe('Decrease Market Order Process', function () {
  let fixture: Fixture
  let tradeVault: TradeVault,
    marketFacet: MarketFacet,
    poolFacet: PoolFacet,
    accountFacet: AccountFacet,
    positionFacet: PositionFacet,
    feeFacet: FeeFacet,
    configFacet: ConfigFacet
  let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner
  let tradeVaultAddr: string,
    portfolioVaultAddr: string,
    wbtcAddr: string,
    wethAddr: string,
    solAddr: string,
    usdcAddr: string
  let btcUsd: string, ethUsd: string, solUsd: string, xBtc: string, xEth: string, xUsd: string
  let wbtc: MockToken, weth: MockToken, sol: MockToken, usdc: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ tradeVault, marketFacet, poolFacet, accountFacet, positionFacet, feeFacet, configFacet } = fixture.contracts)
    ;({ user0, user1, user2 } = fixture.accounts)
    ;({ btcUsd, ethUsd, solUsd } = fixture.symbols)
    ;({ xBtc, xEth, xUsd } = fixture.pools)
    ;({ wbtc, weth, sol, usdc } = fixture.tokens)
    ;({ tradeVaultAddr, portfolioVaultAddr } = fixture.addresses)
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
    const daiTokenPrice = precision.price(99, 6)
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

  it('Case1: Place Single Decrease Market Order Single User/Long Position/PNL < 0', async function () {
    const preTokenBalance = BigInt(await wbtc.balanceOf(user0.address))
    const preVaultBalance = BigInt(await wbtc.balanceOf(tradeVaultAddr))
    const preMarketBalance = BigInt(await wbtc.balanceOf(xBtc))

    const orderMargin1 = precision.token(1, 17) // 0.1BTC
    const btcPrice1 = precision.price(25005)
    const btcOracle1 = [{ token: wbtcAddr, minPrice: btcPrice1, maxPrice: btcPrice1 }]

    const poolInfo1 = await poolFacet.getPool(xBtc)

    // new position
    await handleOrder(fixture, {
      symbol: btcUsd,
      orderMargin: orderMargin1,
      marginToken: wbtc,
      oracle: btcOracle1,
    })

    const symbolInfo = await marketFacet.getSymbol(btcUsd)
    const leverageMargin = precision.mulRate(orderMargin1, precision.rate(10))
    const openFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = orderMargin1 - openFee

    const defaultMarginMode = false
    const positionInfo = await positionFacet.getSinglePosition(user0.address, btcUsd, wbtcAddr, defaultMarginMode)
    expect(initialMargin).to.equals(positionInfo.initialMargin)
    expect(initialMargin * BigInt(25005)).to.equals(positionInfo.initialMarginInUsd)
    expect(true).to.equals(positionInfo.isLong)
    expect(initialMargin * BigInt(10) * BigInt(25005)).to.equals(positionInfo.qty)

    // close position
    const btcPrice2 = precision.price(24900)
    const btcOracle2 = [{ token: wbtcAddr, minPrice: btcPrice2, maxPrice: btcPrice2 }]

    await handleOrder(fixture, {
      symbol: btcUsd,
      marginToken: wbtc,
      orderSide: OrderSide.SHORT,
      posSide: PositionSide.DECREASE,
      qty: positionInfo.qty,
      oracle: btcOracle2,
    })

    const nextTokenBalance = BigInt(await wbtc.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await wbtc.balanceOf(tradeVaultAddr))
    const nextMarketBalance = BigInt(await wbtc.balanceOf(xBtc))

    const closeFeeInUsd = precision.mulRate(positionInfo.qty, symbolInfo.config.closeFeeRate)
    const closeFee = precision.divPrice(closeFeeInUsd, btcPrice2)

    // position
    const positionInfo2 = await positionFacet.getSinglePosition(user0.address, btcUsd, wbtcAddr, defaultMarginMode)
    expect(0).to.equals(positionInfo2.initialMargin)
    expect(0).to.equals(positionInfo2.initialMarginInUsd)
    expect(0).to.equals(positionInfo2.qty)

    const lossInUsd = (positionInfo.qty * (btcPrice2 - btcPrice1)) / btcPrice1

    const initialMarginInUsd = precision.mulPrice(orderMargin1 - openFee, btcPrice1)

    const settleMargin = precision.divPrice(initialMarginInUsd - closeFeeInUsd + lossInUsd, btcPrice2)

    const userPnl = settleMargin - initialMargin
    // wallet
    expect(orderMargin1 - settleMargin).to.equals(nextMarketBalance - preMarketBalance)
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(orderMargin1 - settleMargin).to.equals(preTokenBalance - nextTokenBalance)

    // Account
    const accountInfo = await accountFacet.getAccountInfo(user0.address)
    expect(user0.address).to.equals(accountInfo.owner)

    // pool
    const poolInfo2 = await poolFacet.getPool(xBtc)
    expect(-userPnl).to.equals(poolInfo2.baseTokenBalance.amount - poolInfo1.baseTokenBalance.amount)
    expect(0).to.equals(poolInfo2.baseTokenBalance.holdAmount)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(btcUsd, oracles.format(btcOracle2))
    expect(0).to.equals(marketInfo.longPositionInterest)
  })

  it('Case2: Place Multi Decrease Market Order Single User/Long Position/Pnl > 0', async function () {
    const preTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const preMarketBalance = BigInt(await weth.balanceOf(xEth))

    const orderMargin1 = precision.token(2) // 2ETH
    const ethPrice0 = precision.price(1601)
    const ethOracle0 = [{ token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 }]

    const leverage = BigInt(10)
    const executionFee = precision.token(2, 15)

    // new position
    await handleOrder(fixture, {
      symbol: ethUsd,
      orderMargin: orderMargin1,
      oracle: ethOracle0,
      executionFee: executionFee,
    })

    const poolInfo = await poolFacet.getPool(xEth)
    const symbolInfo = await marketFacet.getSymbol(ethUsd)
    const leverageMargin = precision.mulRate(orderMargin1, precision.rate(leverage))
    const openFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = orderMargin1 - openFee

    const defaultMarginMode = false
    const positionInfo = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(initialMargin).to.equals(positionInfo.initialMargin)
    expect(precision.mulPrice(initialMargin, ethPrice0)).to.equals(positionInfo.initialMarginInUsd)
    expect(true).to.equals(positionInfo.isLong)
    expect(precision.mulPrice(initialMargin * leverage, ethPrice0)).to.equals(positionInfo.qty)

    // close position 1
    const ethPrice1 = precision.price(1610)
    const ethOracle1 = [{ token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 }]

    const closeQty1 = positionInfo.qty / BigInt(3)

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.SHORT,
      posSide: PositionSide.DECREASE,
      qty: closeQty1,
      oracle: ethOracle1,
      executionFee: executionFee,
    })

    const closeFee1 = precision.divPrice(precision.mulRate(closeQty1, symbolInfo.config.closeFeeRate), ethPrice1)
    const closeFee1InUsd = precision.mulPrice(closeFee1, ethPrice1)

    // position
    const positionInfo1 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(positionInfo.initialMargin - (positionInfo.initialMargin * closeQty1) / positionInfo.qty).to.equals(
      positionInfo1.initialMargin,
    )
    expect(
      positionInfo.initialMarginInUsd - (positionInfo.initialMarginInUsd * closeQty1) / positionInfo.qty,
    ).to.equals(positionInfo1.initialMarginInUsd)
    expect(
      positionInfo.initialMarginInUsdFromBalance -
        (positionInfo.initialMarginInUsdFromBalance * closeQty1) / positionInfo.qty,
    ).to.equals(positionInfo1.initialMarginInUsdFromBalance)
    expect(ethPrice0).to.equals(positionInfo1.entryPrice)
    expect(positionInfo.qty - closeQty1).to.equals(positionInfo1.qty)

    const pnlInUsd = (positionInfo.qty * (ethPrice1 - ethPrice0)) / ethPrice0
    const initialMarginInUsd = precision.mulPrice(initialMargin, ethPrice0)

    const settledMargin1 = precision.divPrice(
      ((initialMarginInUsd - closeFee1InUsd + pnlInUsd) * closeQty1) / positionInfo.qty,
      ethPrice1,
    )
    const userPnl1 = settledMargin1 - (initialMargin * closeQty1) / positionInfo.qty

    const nextMarketBalance1 = BigInt(await weth.balanceOf(xEth))
    const nextTokenBalance1 = BigInt(await weth.balanceOf(user0.address))

    // wallet
    expect(orderMargin1 - settledMargin1).to.equals(nextMarketBalance1 - preMarketBalance)
    expect(orderMargin1 - settledMargin1).to.equals(preTokenBalance - nextTokenBalance1)

    // pool
    const poolInfo1 = await poolFacet.getPool(xEth)
    expect(userPnl1 + closeFee1).to.equals(poolInfo.baseTokenBalance.amount - poolInfo1.baseTokenBalance.amount)

    expect(
      poolInfo.baseTokenBalance.holdAmount - (poolInfo.baseTokenBalance.holdAmount * closeQty1) / positionInfo.qty,
    ).to.equals(poolInfo1.baseTokenBalance.holdAmount)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(ethUsd, oracles.format(ethOracle1))
    expect(positionInfo.qty - closeQty1).to.equals(marketInfo.longPositionInterest)

    // close position 2
    const ethPrice2 = precision.price(1680)
    const ethOracle2 = [{ token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 }]

    const closeQty2 = positionInfo.qty / BigInt(3)

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.SHORT,
      posSide: PositionSide.DECREASE,
      qty: closeQty2,
      oracle: ethOracle2,
    })

    const closeFee2InUsd = precision.mulRate(closeQty2, symbolInfo.config.closeFeeRate)
    const closeFee2 = precision.usdToToken(closeFee2InUsd, ethPrice2, 18)

    // position
    const positionInfo2 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(positionInfo1.initialMargin - (positionInfo.initialMargin * closeQty2) / positionInfo.qty).to.equals(
      positionInfo2.initialMargin,
    )
    expect(
      positionInfo1.initialMarginInUsd - (positionInfo.initialMarginInUsd * closeQty2) / positionInfo.qty,
    ).to.equals(positionInfo2.initialMarginInUsd)
    expect(
      positionInfo1.initialMarginInUsdFromBalance -
        (positionInfo.initialMarginInUsdFromBalance * closeQty2) / positionInfo.qty,
    ).to.equals(positionInfo2.initialMarginInUsdFromBalance)
    expect(ethPrice0).to.equals(positionInfo2.entryPrice)
    expect(positionInfo1.qty - closeQty2).to.equals(positionInfo2.qty)

    const pnlInUsd2 = (positionInfo1.qty * (ethPrice2 - ethPrice0)) / ethPrice0

    const settledMargin2 = precision.usdToToken(
      ((positionInfo1.initialMarginInUsd - closeFee2InUsd + pnlInUsd2) * closeQty2) / positionInfo1.qty,
      ethPrice2,
      18,
    )
    const userPnl2 = settledMargin2 - (positionInfo1.initialMargin * closeQty2) / positionInfo1.qty

    const nextMarketBalance2 = BigInt(await weth.balanceOf(xEth))
    const nextTokenBalance2 = BigInt(await weth.balanceOf(user0.address))

    // wallet
    expect(settledMargin2).to.equals(nextMarketBalance1 - nextMarketBalance2)
    expect(settledMargin2).to.equals(nextTokenBalance2 - nextTokenBalance1)

    // pool
    const poolInfo2 = await poolFacet.getPool(xEth)
    expect(userPnl2 + closeFee2).to.equals(poolInfo1.baseTokenBalance.amount - poolInfo2.baseTokenBalance.amount)

    expect(
      poolInfo1.baseTokenBalance.holdAmount - (poolInfo1.baseTokenBalance.holdAmount * closeQty2) / positionInfo1.qty,
    ).to.equals(poolInfo2.baseTokenBalance.holdAmount)

    // Market
    const marketInfo2 = await marketFacet.getMarketInfo(ethUsd, oracles.format(ethOracle2))
    expect(positionInfo1.qty - closeQty2).to.equals(marketInfo2.longPositionInterest)

    // close position 3
    const ethPrice3 = precision.price(1590)
    const ethOracle3 = [{ token: wethAddr, minPrice: ethPrice3, maxPrice: ethPrice3 }]

    const closeQty3 = positionInfo2.qty

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.SHORT,
      posSide: PositionSide.DECREASE,
      qty: closeQty3,
      oracle: ethOracle3,
    })

    const closeFee3InUsd = precision.mulRate(closeQty3, symbolInfo.config.closeFeeRate)
    const closeFee3 = precision.divPrice(closeFee3InUsd, ethPrice3)

    // position
    const positionInfo3 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(0).to.equals(positionInfo3.initialMargin)
    expect(0).to.equals(positionInfo3.initialMarginInUsd)
    expect(0).to.equals(positionInfo3.initialMarginInUsdFromBalance)
    expect(0).to.equals(positionInfo3.qty)

    const pnlInUsd3 = (positionInfo2.qty * (ethPrice3 - ethPrice0)) / ethPrice0

    const settledMargin3 = precision.divPrice(positionInfo2.initialMarginInUsd - closeFee3InUsd + pnlInUsd3, ethPrice3)
    const userPnl3 = settledMargin3 - positionInfo2.initialMargin

    const nextMarketBalance3 = BigInt(await weth.balanceOf(xEth))
    const nextTokenBalance3 = BigInt(await weth.balanceOf(user0.address))

    // wallet
    expect(settledMargin3).to.equals(nextMarketBalance2 - nextMarketBalance3)
    expect(settledMargin3).to.equals(nextTokenBalance3 - nextTokenBalance2)

    // pool
    const poolInfo3 = await poolFacet.getPool(xEth)
    expect(userPnl3).to.equals(poolInfo2.baseTokenBalance.amount - poolInfo3.baseTokenBalance.amount)

    expect(0).to.equals(poolInfo3.baseTokenBalance.holdAmount)

    // Market
    const marketInfo3 = await marketFacet.getMarketInfo(ethUsd, oracles.format(ethOracle3))
    expect(0).to.equals(marketInfo3.longPositionInterest)
  })

  it('Case3: Place Multi Decrease Market Order Single User/Long Position/Pnl < 0', async function () {
    const preTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const preMarketBalance = BigInt(await weth.balanceOf(xEth))

    const orderMargin1 = precision.token(2) // 2ETH
    const ethPrice0 = precision.price(1601)
    const ethOracle0 = [{ token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 }]

    const leverage = BigInt(10)
    const executionFee = precision.token(2, 15)

    // new position
    await handleOrder(fixture, {
      symbol: ethUsd,
      orderMargin: orderMargin1,
      oracle: ethOracle0,
      executionFee: executionFee,
    })

    const poolInfo = await poolFacet.getPool(xEth)
    const symbolInfo = await marketFacet.getSymbol(ethUsd)
    const leverageMargin = precision.mulRate(orderMargin1, precision.rate(leverage))
    const openFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = orderMargin1 - openFee

    const defaultMarginMode = false
    const positionInfo = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(initialMargin).to.equals(positionInfo.initialMargin)
    expect(precision.mulPrice(initialMargin, ethPrice0)).to.equals(positionInfo.initialMarginInUsd)
    expect(true).to.equals(positionInfo.isLong)
    expect(precision.mulPrice(initialMargin * leverage, ethPrice0)).to.equals(positionInfo.qty)

    // close position 1
    const ethPrice1 = precision.price(1590)
    const ethOracle1 = [{ token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 }]

    const closeQty1 = positionInfo.qty / BigInt(3)

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.SHORT,
      posSide: PositionSide.DECREASE,
      qty: closeQty1,
      oracle: ethOracle1,
      executionFee: executionFee,
    })

    const closeFee1 = precision.divPrice(precision.mulRate(closeQty1, symbolInfo.config.closeFeeRate), ethPrice1)
    const closeFee1InUsd = precision.mulPrice(closeFee1, ethPrice1)

    // position
    const positionInfo1 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(positionInfo.initialMargin - (positionInfo.initialMargin * closeQty1) / positionInfo.qty).to.equals(
      positionInfo1.initialMargin,
    )
    expect(
      positionInfo.initialMarginInUsd - (positionInfo.initialMarginInUsd * closeQty1) / positionInfo.qty,
    ).to.equals(positionInfo1.initialMarginInUsd)
    expect(
      positionInfo.initialMarginInUsdFromBalance -
        (positionInfo.initialMarginInUsdFromBalance * closeQty1) / positionInfo.qty,
    ).to.equals(positionInfo1.initialMarginInUsdFromBalance)
    expect(ethPrice0).to.equals(positionInfo1.entryPrice)
    expect(positionInfo.qty - closeQty1).to.equals(positionInfo1.qty)

    const pnlInUsd = (positionInfo.qty * (ethPrice1 - ethPrice0)) / ethPrice0
    const initialMarginInUsd = precision.mulPrice(initialMargin, ethPrice0)

    const settledMargin1 =
      (precision.divPrice(initialMarginInUsd - closeFee1InUsd + pnlInUsd, ethPrice1) * closeQty1) / positionInfo.qty
    const userPnl1 = settledMargin1 - (initialMargin * closeQty1) / positionInfo.qty

    const nextMarketBalance1 = BigInt(await weth.balanceOf(xEth))
    const nextTokenBalance1 = BigInt(await weth.balanceOf(user0.address))

    // wallet
    expect(orderMargin1 - settledMargin1).to.equals(nextMarketBalance1 - preMarketBalance)
    expect(orderMargin1 - settledMargin1).to.equals(preTokenBalance - nextTokenBalance1)

    // pool
    const poolInfo1 = await poolFacet.getPool(xEth)
    expect(userPnl1).to.equals(poolInfo.baseTokenBalance.amount - poolInfo1.baseTokenBalance.amount)

    expect(
      poolInfo.baseTokenBalance.holdAmount - (poolInfo.baseTokenBalance.holdAmount * closeQty1) / positionInfo.qty,
    ).to.equals(poolInfo1.baseTokenBalance.holdAmount)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(ethUsd, oracles.format(ethOracle1))
    expect(positionInfo.qty - closeQty1).to.equals(marketInfo.longPositionInterest)

    // close position 2
    const ethPrice2 = precision.price(1578)
    const ethOracle2 = [{ token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 }]

    const closeQty2 = positionInfo.qty / BigInt(3)

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.SHORT,
      posSide: PositionSide.DECREASE,
      qty: closeQty2,
      oracle: ethOracle2,
    })

    const closeFee2InUsd = precision.mulRate(closeQty2, symbolInfo.config.closeFeeRate)
    const closeFee2 = precision.divPrice(closeFee2InUsd, ethPrice2)

    // position
    const positionInfo2 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(positionInfo1.initialMargin - (positionInfo.initialMargin * closeQty2) / positionInfo.qty).to.equals(
      positionInfo2.initialMargin,
    )
    expect(
      positionInfo1.initialMarginInUsd - (positionInfo.initialMarginInUsd * closeQty2) / positionInfo.qty,
    ).to.equals(positionInfo2.initialMarginInUsd)
    expect(
      positionInfo1.initialMarginInUsdFromBalance -
        (positionInfo.initialMarginInUsdFromBalance * closeQty2) / positionInfo.qty,
    ).to.equals(positionInfo2.initialMarginInUsdFromBalance)
    expect(ethPrice0).to.equals(positionInfo2.entryPrice)
    expect(positionInfo1.qty - closeQty2).to.equals(positionInfo2.qty)

    const pnlInUsd2 = (positionInfo1.qty * (ethPrice2 - ethPrice0)) / ethPrice0

    const settledMargin2 = precision.divPrice(
      ((positionInfo1.initialMarginInUsd - closeFee2InUsd + pnlInUsd2) * closeQty2) / positionInfo1.qty,
      ethPrice2,
    )
    const userPnl2 = settledMargin2 - (positionInfo1.initialMargin * closeQty2) / positionInfo1.qty

    const nextMarketBalance2 = BigInt(await weth.balanceOf(xEth))
    const nextTokenBalance2 = BigInt(await weth.balanceOf(user0.address))

    // wallet
    expect(settledMargin2).to.equals(nextMarketBalance1 - nextMarketBalance2)
    expect(settledMargin2).to.equals(nextTokenBalance2 - nextTokenBalance1)

    // pool
    const poolInfo2 = await poolFacet.getPool(xEth)
    expect(userPnl2).to.equals(poolInfo1.baseTokenBalance.amount - poolInfo2.baseTokenBalance.amount)

    expect(
      poolInfo1.baseTokenBalance.holdAmount - (poolInfo1.baseTokenBalance.holdAmount * closeQty2) / positionInfo1.qty,
    ).to.equals(poolInfo2.baseTokenBalance.holdAmount)

    // Market
    const marketInfo2 = await marketFacet.getMarketInfo(ethUsd, oracles.format(ethOracle2))
    expect(positionInfo1.qty - closeQty2).to.equals(marketInfo2.longPositionInterest)

    // close position 3
    const ethPrice3 = precision.price(1570)
    const ethOracle3 = [{ token: wethAddr, minPrice: ethPrice3, maxPrice: ethPrice3 }]

    const closeQty3 = positionInfo2.qty

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.SHORT,
      posSide: PositionSide.DECREASE,
      qty: closeQty3,
      oracle: ethOracle3,
    })

    const closeFee3 = precision.divPrice(precision.mulRate(closeQty3, symbolInfo.config.closeFeeRate), ethPrice3)
    const closeFee3InUsd = precision.mulPrice(closeFee3, ethPrice3)

    // position
    const positionInfo3 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, defaultMarginMode)
    expect(0).to.equals(positionInfo3.initialMargin)
    expect(0).to.equals(positionInfo3.initialMarginInUsd)
    expect(0).to.equals(positionInfo3.initialMarginInUsdFromBalance)
    expect(0).to.equals(positionInfo3.qty)

    const pnlInUsd3 = (positionInfo2.qty * (ethPrice3 - ethPrice0)) / ethPrice0

    const settledMargin3 = precision.divPrice(positionInfo2.initialMarginInUsd - closeFee3InUsd + pnlInUsd3, ethPrice3)
    const userPnl3 = settledMargin3 - positionInfo2.initialMargin

    const nextMarketBalance3 = BigInt(await weth.balanceOf(xEth))
    const nextTokenBalance3 = BigInt(await weth.balanceOf(user0.address))

    // wallet
    expect(settledMargin3).to.equals(nextMarketBalance2 - nextMarketBalance3)
    expect(settledMargin3).to.equals(nextTokenBalance3 - nextTokenBalance2)

    // pool
    const poolInfo3 = await poolFacet.getPool(xEth)
    expect(userPnl3).to.equals(poolInfo2.baseTokenBalance.amount - poolInfo3.baseTokenBalance.amount)

    expect(0).to.equals(poolInfo3.baseTokenBalance.holdAmount)

    // Market
    const marketInfo3 = await marketFacet.getMarketInfo(ethUsd, oracles.format(ethOracle3))
    expect(0).to.equals(marketInfo3.longPositionInterest)
  })

  it('Case4: Place Multi Decrease Market Order Single User/Short Position/Pnl > 0', async function () {
    const preTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const preMarketBalance = BigInt(await usdc.balanceOf(xEth))
    const prePfVaultBalance = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    const preUsdVaultBalance = BigInt(await usdc.balanceOf(xUsd))

    const orderMargin1 = precision.token(1000, 6) // 1000USDT
    const usdtPrice0 = precision.price(1)
    const ethPrice0 = precision.price(1600)
    const oracle0 = [
      { token: usdcAddr, minPrice: usdtPrice0, maxPrice: usdtPrice0 },
      { token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 },
    ]

    const leverage = BigInt(10)

    // new position
    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.SHORT,
      orderMargin: orderMargin1,
      marginToken: usdc,
      oracle: oracle0,
    })

    const xtokenPoolInfo = await poolFacet.getPool(xEth)
    const xUsdPoolInfo = await poolFacet.getUsdPool()
    const symbolInfo = await marketFacet.getSymbol(ethUsd)

    const leverageMargin = precision.mulRate(orderMargin1, precision.rate(leverage))
    const openFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = orderMargin1 - openFee

    const defaultMarginMode = false
    const positionInfo = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(initialMargin).to.equals(positionInfo.initialMargin)

    expect(precision.usd(precision.mulPrice(initialMargin, usdtPrice0), 18 - 6)).to.equals(
      positionInfo.initialMarginInUsd,
    )
    expect(false).to.equals(positionInfo.isLong)
    expect(precision.usd(precision.mulPrice(initialMargin * leverage, usdtPrice0), 18 - 6)).to.equals(positionInfo.qty)

    const nextMarketBalance0 = BigInt(await usdc.balanceOf(xEth))
    const nextPfVaultBalance0 = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    const nextTokenBalance0 = BigInt(await usdc.balanceOf(user0.address))
    expect(orderMargin1).to.equals(nextMarketBalance0 - preMarketBalance)
    expect(0).to.equals(nextPfVaultBalance0 - prePfVaultBalance)

    // close position 1
    const usdtPrice1 = precision.price(1)
    const ethPrice1 = precision.price(1592)
    const oracle1 = [
      { token: usdcAddr, minPrice: usdtPrice1, maxPrice: usdtPrice1 },
      { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
    ]

    const closeQty1 = positionInfo.qty / BigInt(3)

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.LONG,
      posSide: PositionSide.DECREASE,
      marginToken: usdc,
      qty: closeQty1,
      oracle: oracle1,
    })

    const closeFee1 =
      precision.divPrice(precision.mulRate(closeQty1, symbolInfo.config.closeFeeRate), usdtPrice1) /
      BigInt(10 ** (18 - 6))
    const closeFee1InUsd = precision.usd(precision.mulPrice(closeFee1, usdtPrice1), 18 - 6)

    // position
    const positionInfo1 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(positionInfo.initialMargin - (positionInfo.initialMargin * closeQty1) / positionInfo.qty).to.equals(
      positionInfo1.initialMargin,
    )
    expect(
      positionInfo.initialMarginInUsd - (positionInfo.initialMarginInUsd * closeQty1) / positionInfo.qty,
    ).to.equals(positionInfo1.initialMarginInUsd)
    expect(
      positionInfo.initialMarginInUsdFromBalance -
        (positionInfo.initialMarginInUsdFromBalance * closeQty1) / positionInfo.qty,
    ).to.equals(positionInfo1.initialMarginInUsdFromBalance)
    expect(ethPrice0).to.equals(positionInfo1.entryPrice)
    expect(positionInfo.qty - closeQty1).to.equals(positionInfo1.qty)

    const accountInfo1 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle1))

    const pnlInUsd = (positionInfo.qty * (ethPrice0 - ethPrice1)) / ethPrice0
    const initialMarginInUsd = precision.usd(precision.mulPrice(initialMargin, usdtPrice0), 18 - 6)

    const settledMargin1 =
      (precision.divPrice(initialMarginInUsd - closeFee1InUsd + pnlInUsd, usdtPrice1) * closeQty1) /
      positionInfo.qty /
      BigInt(10 ** (18 - 6))

    const userPnl1 = settledMargin1 - (initialMargin * closeQty1) / positionInfo.qty
    const nextMarketBalance1 = BigInt(await usdc.balanceOf(xEth))
    const nextPfVaultBalance1 = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    const nextUsdVaultBalance1 = BigInt(await usdc.balanceOf(xUsd))
    const nextTokenBalance1 = BigInt(await usdc.balanceOf(user0.address))

    // wallet
    expect(closeFee1 + userPnl1 - settledMargin1).to.equals(nextMarketBalance1 - nextMarketBalance0)
    expect(closeFee1 + userPnl1).to.equals(preUsdVaultBalance - nextUsdVaultBalance1)
    expect(0).to.equals(nextPfVaultBalance1 - nextPfVaultBalance0)
    expect(settledMargin1).to.equals(nextTokenBalance1 - nextTokenBalance0)

    // pool
    const xtokenPoolInfo1 = await poolFacet.getPool(xEth)
    const xUsdPoolInfo1 = await poolFacet.getUsdPool()
    expect(userPnl1 + closeFee1).to.equals(xtokenPoolInfo1.stableTokenBalances[0].lossAmount)
    expect(userPnl1 + closeFee1).to.equals(
      xUsdPoolInfo.stableTokenBalances[0].amount - xUsdPoolInfo1.stableTokenBalances[0].amount,
    )
    expect(userPnl1 + closeFee1).to.equals(
      xUsdPoolInfo1.stableTokenBalances[0].unsettledAmount - xUsdPoolInfo.stableTokenBalances[0].unsettledAmount,
    )
    expect(
      xUsdPoolInfo.stableTokenBalances[0].holdAmount -
        (xUsdPoolInfo.stableTokenBalances[0].holdAmount * closeQty1) / positionInfo.qty,
    ).to.equals(xUsdPoolInfo1.stableTokenBalances[0].holdAmount)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(ethUsd, oracles.format(oracle1))
    expect(positionInfo.qty - closeQty1).to.equals(marketInfo.totalShortPositionInterest)

    // close position 2
    const usdtPrice2 = precision.price(1)
    const ethPrice2 = precision.price(1580)
    const oracle2 = [
      { token: usdcAddr, minPrice: usdtPrice2, maxPrice: usdtPrice2 },
      { token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 },
    ]

    const closeQty2 = positionInfo.qty / BigInt(3)

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.LONG,
      posSide: PositionSide.DECREASE,
      marginToken: usdc,
      qty: closeQty2,
      oracle: oracle2,
    })

    const accountInfo2 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle2))
    const nextMarketBalance2 = BigInt(await usdc.balanceOf(xEth))
    const nextPfVaultBalance2 = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    const nextUsdVaultBalance2 = BigInt(await usdc.balanceOf(xUsd))
    const nextTokenBalance2 = BigInt(await usdc.balanceOf(user0.address))

    const closeFee2 =
      precision.divPrice(precision.mulRate(closeQty2, symbolInfo.config.closeFeeRate), usdtPrice2) / BigInt(10 ** 12)
    const closeFee2InUsd = precision.usd(precision.mulPrice(closeFee2, usdtPrice2), 18 - 6)

    // position
    const positionInfo2 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(positionInfo1.initialMargin - (positionInfo1.initialMargin * closeQty2) / positionInfo1.qty).to.equals(
      positionInfo2.initialMargin,
    )
    expect(
      positionInfo1.initialMarginInUsd - (positionInfo1.initialMarginInUsd * closeQty2) / positionInfo1.qty,
    ).to.equals(positionInfo2.initialMarginInUsd)
    expect(
      positionInfo1.initialMarginInUsdFromBalance -
        (positionInfo1.initialMarginInUsdFromBalance * closeQty2) / positionInfo1.qty,
    ).to.equals(positionInfo2.initialMarginInUsdFromBalance)
    expect(ethPrice0).to.equals(positionInfo2.entryPrice)
    expect(positionInfo1.qty - closeQty2).to.equals(positionInfo2.qty)

    const pnlInUsd2 = (positionInfo1.qty * (ethPrice0 - ethPrice2)) / ethPrice0

    const settledMargin2 =
      (precision.divPrice(positionInfo1.initialMarginInUsd - closeFee2InUsd + pnlInUsd2, usdtPrice2) * closeQty2) /
      positionInfo1.qty /
      BigInt(10 ** 12)
    const userPnl2 = settledMargin2 - (positionInfo1.initialMargin * closeQty2) / positionInfo1.qty

    // wallet
    expect(closeFee2 + userPnl2 - settledMargin2).to.equals(nextMarketBalance2 - nextMarketBalance1)
    expect(closeFee2 + userPnl2).to.equals(nextUsdVaultBalance1 - nextUsdVaultBalance2)
    expect(settledMargin2).to.equals(nextTokenBalance2 - nextTokenBalance1)
    expect(0).to.equals(nextPfVaultBalance2 - nextPfVaultBalance1)

    // pool
    const xtokenPoolInfo2 = await poolFacet.getPool(xEth)
    const xUsdPoolInfo2 = await poolFacet.getUsdPool()

    expect(userPnl2 + closeFee2).to.equals(
      xtokenPoolInfo2.stableTokenBalances[0].lossAmount - xtokenPoolInfo1.stableTokenBalances[0].lossAmount,
    )
    expect(userPnl2 + closeFee2).to.equals(
      xUsdPoolInfo1.stableTokenBalances[0].amount - xUsdPoolInfo2.stableTokenBalances[0].amount,
    )
    expect(userPnl2 + closeFee2).to.equals(
      xUsdPoolInfo2.stableTokenBalances[0].unsettledAmount - xUsdPoolInfo1.stableTokenBalances[0].unsettledAmount,
    )
    expect(
      xUsdPoolInfo1.stableTokenBalances[0].holdAmount -
        (xUsdPoolInfo1.stableTokenBalances[0].holdAmount * closeQty2) / positionInfo1.qty,
    ).to.equals(xUsdPoolInfo2.stableTokenBalances[0].holdAmount)

    // Market
    const marketInfo2 = await marketFacet.getMarketInfo(ethUsd, oracles.format(oracle2))
    expect(positionInfo1.qty - closeQty2).to.equals(marketInfo2.totalShortPositionInterest)

    // close position 3
    const usdtPrice3 = precision.price(1)
    const ethPrice3 = precision.price(1570)
    const oracle3 = [
      { token: usdcAddr, minPrice: usdtPrice3, maxPrice: usdtPrice3 },
      { token: wethAddr, minPrice: ethPrice3, maxPrice: ethPrice3 },
    ]
    const closeQty3 = positionInfo2.qty

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.LONG,
      posSide: PositionSide.DECREASE,
      marginToken: usdc,
      qty: closeQty3,
      oracle: oracle3,
    })

    const accountInfo3 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle3))

    const closeFee3 =
      precision.divPrice(precision.mulRate(closeQty3, symbolInfo.config.closeFeeRate), usdtPrice3) / BigInt(10 ** 12)
    const closeFee3InUsd = precision.usd(precision.mulPrice(closeFee3, usdtPrice3), 18 - 6)

    // position
    const positionInfo3 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(0).to.equals(positionInfo3.initialMargin)
    expect(0).to.equals(positionInfo3.initialMarginInUsd)
    expect(0).to.equals(positionInfo3.initialMarginInUsdFromBalance)
    expect(0).to.equals(positionInfo3.qty)

    const pnlInUsd3 = (positionInfo2.qty * (ethPrice0 - ethPrice3)) / ethPrice0

    const settledMargin3 =
      precision.divPrice(positionInfo2.initialMarginInUsd - closeFee3InUsd + pnlInUsd3, usdtPrice3) / BigInt(10 ** 12)
    const userPnl3 = settledMargin3 - positionInfo2.initialMargin

    const nextMarketBalance3 = BigInt(await usdc.balanceOf(xEth))
    const nextPfVaultBalance3 = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    const nextUsdVaultBalance3 = BigInt(await usdc.balanceOf(xUsd))
    const nextTokenBalance3 = BigInt(await usdc.balanceOf(user0.address))

    // wallet
    expect(0).to.equals(nextPfVaultBalance3 - nextPfVaultBalance2)
    expect(closeFee3 + userPnl3).to.equals(nextUsdVaultBalance2 - nextUsdVaultBalance3)
    expect(closeFee3 + userPnl3 - settledMargin3).to.equals(nextMarketBalance3 - nextMarketBalance2)
    expect(settledMargin3).to.equals(nextTokenBalance3 - nextTokenBalance2)

    // pool
    const xtokenPoolInfo3 = await poolFacet.getPool(xEth)
    const xUsdPoolInfo3 = await poolFacet.getUsdPool()

    expect(userPnl3 + closeFee3).to.equals(
      xtokenPoolInfo3.stableTokenBalances[0].lossAmount - xtokenPoolInfo2.stableTokenBalances[0].lossAmount,
    )
    expect(userPnl3 + closeFee3).to.equals(
      xUsdPoolInfo2.stableTokenBalances[0].amount - xUsdPoolInfo3.stableTokenBalances[0].amount,
    )
    expect(userPnl3 + closeFee3).to.equals(
      xUsdPoolInfo3.stableTokenBalances[0].unsettledAmount - xUsdPoolInfo2.stableTokenBalances[0].unsettledAmount,
    )
    expect(0).to.equals(xUsdPoolInfo3.stableTokenBalances[0].holdAmount)

    // Market
    const marketInfo3 = await marketFacet.getMarketInfo(ethUsd, oracles.format(oracle3))
    expect(0).to.equals(marketInfo3.totalShortPositionInterest)
  })

  it('Case5: Place Multi Decrease Market Order Single User/Short Position/Pnl < 0', async function () {
    const preTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const preMarketBalance = BigInt(await usdc.balanceOf(xEth))
    const prePfVaultBalance = BigInt(await usdc.balanceOf(portfolioVaultAddr))

    const orderMargin1 = precision.token(1000, 6) // 1000USDT
    const usdtPrice0 = precision.price(1)
    const ethPrice0 = precision.price(1600)
    const oracle0 = [
      { token: usdcAddr, minPrice: usdtPrice0, maxPrice: usdtPrice0 },
      { token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 },
    ]

    const leverage = BigInt(10)

    // new position
    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.SHORT,
      orderMargin: orderMargin1,
      marginToken: usdc,
      oracle: oracle0,
    })

    const xtokenPoolInfo = await poolFacet.getPool(xEth)
    const xUsdPoolInfo = await poolFacet.getUsdPool()
    const symbolInfo = await marketFacet.getSymbol(ethUsd)
    const nextMarketBalance0 = BigInt(await usdc.balanceOf(xEth))
    const nextTokenBalance0 = BigInt(await usdc.balanceOf(user0.address))
    const nextPfVaultBalance0 = BigInt(await usdc.balanceOf(portfolioVaultAddr))

    const leverageMargin = precision.mulRate(orderMargin1, precision.rate(leverage))
    const openFee = precision.mulRate(leverageMargin, symbolInfo.config.openFeeRate)
    const initialMargin = orderMargin1 - openFee

    const defaultMarginMode = false
    const positionInfo = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(initialMargin).to.equals(positionInfo.initialMargin)

    expect(precision.usd(precision.mulPrice(initialMargin, usdtPrice0), 18 - 6)).to.equals(
      positionInfo.initialMarginInUsd,
    )
    expect(false).to.equals(positionInfo.isLong)
    expect(precision.usd(precision.mulPrice(initialMargin * leverage, usdtPrice0), 18 - 6)).to.equals(positionInfo.qty)

    // close position 1
    const usdtPrice1 = precision.price(1)
    const ethPrice1 = precision.price(1608)
    const oracle1 = [
      { token: usdcAddr, minPrice: usdtPrice1, maxPrice: usdtPrice1 },
      { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
    ]

    const closeQty1 = positionInfo.qty / BigInt(3)

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.LONG,
      posSide: PositionSide.DECREASE,
      marginToken: usdc,
      qty: closeQty1,
      oracle: oracle1,
    })

    const closeFee1InUsd = precision.mulRate(closeQty1, symbolInfo.config.closeFeeRate)
    const closeFee1 = precision.divPrice(closeFee1InUsd, usdtPrice1) / BigInt(10 ** (18 - 6))

    // position
    const positionInfo1 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(positionInfo.initialMargin - (positionInfo.initialMargin * closeQty1) / positionInfo.qty).to.equals(
      positionInfo1.initialMargin,
    )
    expect(
      positionInfo.initialMarginInUsd - (positionInfo.initialMarginInUsd * closeQty1) / positionInfo.qty,
    ).to.equals(positionInfo1.initialMarginInUsd)
    expect(
      positionInfo.initialMarginInUsdFromBalance -
        (positionInfo.initialMarginInUsdFromBalance * closeQty1) / positionInfo.qty,
    ).to.equals(positionInfo1.initialMarginInUsdFromBalance)
    expect(ethPrice0).to.equals(positionInfo1.entryPrice)
    expect(positionInfo.qty - closeQty1).to.equals(positionInfo1.qty)

    const pnlInUsd = (positionInfo.qty * (ethPrice0 - ethPrice1)) / ethPrice0
    const initialMarginInUsd = precision.usd(precision.mulPrice(initialMargin, usdtPrice0), 18 - 6)

    const settledMargin1 =
      (precision.divPrice(initialMarginInUsd - closeFee1InUsd + pnlInUsd, usdtPrice1) * closeQty1) /
      positionInfo.qty /
      BigInt(10 ** (18 - 6))

    const userPnl1 = settledMargin1 - (initialMargin * closeQty1) / positionInfo.qty

    const nextMarketBalance1 = BigInt(await usdc.balanceOf(xEth))
    const nextTokenBalance1 = BigInt(await usdc.balanceOf(user0.address))
    const nextPfVaultBalance1 = BigInt(await usdc.balanceOf(portfolioVaultAddr))

    // wallet
    expect(-settledMargin1).to.equals(nextMarketBalance1 - nextMarketBalance0)
    expect(0).to.equals(nextPfVaultBalance1 - nextPfVaultBalance0)
    expect(settledMargin1).to.equals(nextTokenBalance1 - nextTokenBalance0)

    // pool
    const xtokenPoolInfo1 = await poolFacet.getPool(xEth)
    const xUsdPoolInfo1 = await poolFacet.getUsdPool()
    expect(-userPnl1).to.equals(xtokenPoolInfo1.stableTokenBalances[0].amount)
    expect(0).to.equals(xUsdPoolInfo.stableTokenBalances[0].amount - xUsdPoolInfo1.stableTokenBalances[0].amount)
    expect(0).to.equals(
      xUsdPoolInfo1.stableTokenBalances[0].unsettledAmount - xUsdPoolInfo.stableTokenBalances[0].unsettledAmount,
    )
    expect(
      xUsdPoolInfo.stableTokenBalances[0].holdAmount -
        (xUsdPoolInfo.stableTokenBalances[0].holdAmount * closeQty1) / positionInfo.qty,
    ).to.equals(xUsdPoolInfo1.stableTokenBalances[0].holdAmount)

    // Market
    const marketInfo = await marketFacet.getMarketInfo(ethUsd, oracles.format(oracle1))
    expect(positionInfo.qty - closeQty1).to.equals(marketInfo.totalShortPositionInterest)

    // close position 2
    const usdtPrice2 = precision.price(1)
    const ethPrice2 = precision.price(1612)
    const oracle2 = [
      { token: usdcAddr, minPrice: usdtPrice2, maxPrice: usdtPrice2 },
      { token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 },
    ]

    const closeQty2 = positionInfo.qty / BigInt(3)

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.LONG,
      posSide: PositionSide.DECREASE,
      marginToken: usdc,
      qty: closeQty2,
      oracle: oracle2,
    })

    const closeFee2InUsd = precision.mulRate(closeQty2, symbolInfo.config.closeFeeRate)
    const closeFee2 = precision.divPrice(closeFee2InUsd, usdtPrice2) / BigInt(10 ** 12)

    // position
    const positionInfo2 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(positionInfo1.initialMargin - (positionInfo.initialMargin * closeQty2) / positionInfo.qty).to.equals(
      positionInfo2.initialMargin,
    )
    expect(
      positionInfo1.initialMarginInUsd - (positionInfo.initialMarginInUsd * closeQty2) / positionInfo.qty,
    ).to.equals(positionInfo2.initialMarginInUsd)
    expect(
      positionInfo1.initialMarginInUsdFromBalance -
        (positionInfo.initialMarginInUsdFromBalance * closeQty2) / positionInfo.qty,
    ).to.equals(positionInfo2.initialMarginInUsdFromBalance)
    expect(ethPrice0).to.equals(positionInfo2.entryPrice)
    expect(positionInfo1.qty - closeQty2).to.equals(positionInfo2.qty)

    const pnlInUsd2 = (positionInfo1.qty * (ethPrice0 - ethPrice2)) / ethPrice0

    const settledMargin2 =
      (precision.divPrice(positionInfo1.initialMarginInUsd - closeFee2InUsd + pnlInUsd2, usdtPrice2) * closeQty2) /
      positionInfo1.qty /
      BigInt(10 ** 12)
    const userPnl2 = settledMargin2 - (positionInfo1.initialMargin * closeQty2) / positionInfo1.qty

    const nextMarketBalance2 = BigInt(await usdc.balanceOf(xEth))
    const nextPfVaultBalance2 = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    const nextTokenBalance2 = BigInt(await usdc.balanceOf(user0.address))

    // wallet
    expect(-settledMargin2).to.equals(nextMarketBalance2 - nextMarketBalance1)
    expect(0).to.equals(nextPfVaultBalance2 - nextPfVaultBalance1)
    expect(settledMargin2).to.equals(nextTokenBalance2 - nextTokenBalance1)

    // pool
    const xtokenPoolInfo2 = await poolFacet.getPool(xEth)
    const xUsdPoolInfo2 = await poolFacet.getUsdPool()

    expect(-userPnl2).to.equals(
      xtokenPoolInfo2.stableTokenBalances[0].amount - xtokenPoolInfo1.stableTokenBalances[0].amount,
    )
    expect(0).to.equals(xUsdPoolInfo1.stableTokenBalances[0].amount - xUsdPoolInfo2.stableTokenBalances[0].amount)
    expect(0).to.equals(
      xUsdPoolInfo2.stableTokenBalances[0].unsettledAmount - xUsdPoolInfo1.stableTokenBalances[0].unsettledAmount,
    )
    expect(
      xUsdPoolInfo1.stableTokenBalances[0].holdAmount -
        (xUsdPoolInfo1.stableTokenBalances[0].holdAmount * closeQty2) / positionInfo1.qty,
    ).to.equals(xUsdPoolInfo2.stableTokenBalances[0].holdAmount)

    // Market
    const marketInfo2 = await marketFacet.getMarketInfo(ethUsd, oracles.format(oracle2))
    expect(positionInfo1.qty - closeQty2).to.equals(marketInfo2.totalShortPositionInterest)

    // close position 3
    const usdtPrice3 = precision.price(1)
    const ethPrice3 = precision.price(1622)
    const oracle3 = [
      { token: usdcAddr, minPrice: usdtPrice3, maxPrice: usdtPrice3 },
      { token: wethAddr, minPrice: ethPrice3, maxPrice: ethPrice3 },
    ]

    const closeQty3 = positionInfo2.qty

    await handleOrder(fixture, {
      symbol: ethUsd,
      orderSide: OrderSide.LONG,
      posSide: PositionSide.DECREASE,
      marginToken: usdc,
      qty: closeQty3,
      oracle: oracle3,
    })

    const closeFee3InUsd = precision.mulRate(closeQty3, symbolInfo.config.closeFeeRate)
    const closeFee3 = precision.divPrice(closeFee3InUsd, usdtPrice3) / BigInt(10 ** 12)

    // position
    const positionInfo3 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(0).to.equals(positionInfo3.initialMargin)
    expect(0).to.equals(positionInfo3.initialMarginInUsd)
    expect(0).to.equals(positionInfo3.initialMarginInUsdFromBalance)
    expect(0).to.equals(positionInfo3.qty)

    const pnlInUsd3 = (positionInfo2.qty * (ethPrice0 - ethPrice3)) / ethPrice0

    const settledMargin3 =
      precision.divPrice(positionInfo2.initialMarginInUsd - closeFee3InUsd + pnlInUsd3, usdtPrice3) / BigInt(10 ** 12)
    const userPnl3 = settledMargin3 - positionInfo2.initialMargin

    const nextMarketBalance3 = BigInt(await usdc.balanceOf(xEth))
    const nextPfVaultBalance3 = BigInt(await usdc.balanceOf(portfolioVaultAddr))
    const nextTokenBalance3 = BigInt(await usdc.balanceOf(user0.address))

    // wallet
    expect(-settledMargin3).to.equals(nextMarketBalance3 - nextMarketBalance2)
    expect(0).to.equals(nextPfVaultBalance3 - nextPfVaultBalance2)
    expect(settledMargin3).to.equals(nextTokenBalance3 - nextTokenBalance2)

    // pool
    const xtokenPoolInfo3 = await poolFacet.getPool(xEth)
    const xUsdPoolInfo3 = await poolFacet.getUsdPool()

    expect(-userPnl3).to.equals(
      xtokenPoolInfo3.stableTokenBalances[0].amount - xtokenPoolInfo2.stableTokenBalances[0].amount,
    )
    expect(0).to.equals(xUsdPoolInfo2.stableTokenBalances[0].amount - xUsdPoolInfo3.stableTokenBalances[0].amount)
    expect(0).to.equals(
      xUsdPoolInfo3.stableTokenBalances[0].unsettledAmount - xUsdPoolInfo2.stableTokenBalances[0].unsettledAmount,
    )
    expect(0).to.equals(xUsdPoolInfo3.stableTokenBalances[0].holdAmount)

    // Market
    const marketInfo3 = await marketFacet.getMarketInfo(ethUsd, oracles.format(oracle3))
    expect(0).to.equals(marketInfo3.totalShortPositionInterest)
  })

})
