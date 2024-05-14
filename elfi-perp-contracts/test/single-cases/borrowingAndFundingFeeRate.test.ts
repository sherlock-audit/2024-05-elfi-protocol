import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { precision } from '@utils/precision'
import {
  AccountFacet,
  ConfigFacet,
  FeeFacet,
  MarketFacet,
  MockToken,
  OrderFacet,
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
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { pool } from '@utils/pool'
import { configs } from '@utils/configs'
import { configUtils } from '@utils/config'

describe('Borrowing And Funding Rate Process', function () {
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
    usdcAddr: string
  let btcUsd: string, ethUsd: string, xBtc: string, xEth: string, xUsd: string
  let wbtc: MockToken, weth: MockToken, usdc: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ tradeVault, marketFacet, poolFacet, accountFacet, positionFacet, feeFacet, configFacet } = fixture.contracts)
    ;({ user0, user1, user2 } = fixture.accounts)
    ;({ btcUsd, ethUsd } = fixture.symbols)
    ;({ xBtc, xEth, xUsd } = fixture.pools)
    ;({ wbtc, weth, usdc } = fixture.tokens)
    ;({ tradeVaultAddr, portfolioVaultAddr } = fixture.addresses)
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

  it('Case1: Update Borrowing Fee Rate & Charge Borrowing Fee / BTC Long', async function () {
    const symbolInfo = await marketFacet.getSymbol(btcUsd)

    const orderMargin0 = precision.token(3) // 3BTC
    const btcPrice0 = precision.price(25005)
    const oracle0 = [{ token: wbtcAddr, minPrice: btcPrice0, maxPrice: btcPrice0 }]

    const leverage = precision.rate(10)

    // config
    const poolConfig = await configFacet.getPoolConfig(xBtc)

    // user0 new position 1
    await handleOrder(fixture, {
      symbol: btcUsd,
      orderMargin: orderMargin0,
      marginToken: wbtc,
      leverage: leverage,
      oracle: oracle0,
      account: user0,
    })

    const leverageMargin1 = precision.mulRate(orderMargin0, leverage)
    const openFee1 = precision.mulRate(leverageMargin1, symbolInfo.config.openFeeRate)
    const initialMargin1 = orderMargin0 - openFee1

    // position update
    const defaultMarginMode = false
    const positionInfo1 = await positionFacet.getSinglePosition(user0.address, btcUsd, wbtcAddr, defaultMarginMode)
    expect(initialMargin1).to.equals(positionInfo1.initialMargin)
    expect(initialMargin1 * BigInt(25005)).to.equals(positionInfo1.initialMarginInUsd)
    expect(true).to.equals(positionInfo1.isLong)
    expect(initialMargin1 * BigInt(10) * BigInt(25005)).to.equals(positionInfo1.qty)
    expect(initialMargin1 * BigInt(9)).to.equals(positionInfo1.holdPoolAmount)

    const closeFeeInUsd1 = precision.mulRate(positionInfo1.qty, symbolInfo.config.closeFeeRate)
    expect(closeFeeInUsd1).to.equals(positionInfo1.positionFee.closeFeeInUsd)
    expect(0).to.equals(positionInfo1.positionFee.openBorrowingFeePerToken)
    expect(0).to.equals(positionInfo1.positionFee.realizedBorrowingFee)
    expect(0).to.equals(positionInfo1.positionFee.realizedBorrowingFeeInUsd)

    // pool update
    const poolInfo1 = await poolFacet.getPool(xBtc)
    expect(0).to.equals(poolInfo1.borrowingFee.cumulativeBorrowingFeePerToken)
    expect(0).to.equals(poolInfo1.borrowingFee.totalBorrowingFee)
    expect(0).to.equals(poolInfo1.borrowingFee.totalRealizedBorrowingFee)
    const lastestTime1 = BigInt(await time.latest())
    expect(lastestTime1).to.equals(poolInfo1.borrowingFee.lastUpdateTime)
    expect(initialMargin1 * BigInt(9)).to.equals(poolInfo1.baseTokenBalance.holdAmount)

    await time.increase(2 * 60 * 60)

    const orderMargin1 = precision.token(11, 17) // 1.1BTC
    const btcPrice1 = precision.price(25105)
    const oracle1 = [{ token: wbtcAddr, minPrice: btcPrice1, maxPrice: btcPrice1 }]

    // user0 add position 2
    await handleOrder(fixture, {
      symbol: btcUsd,
      orderMargin: orderMargin1,
      marginToken: wbtc,
      leverage: leverage,
      oracle: oracle1,
      account: user0,
    })

    const lastestTime2 = BigInt(await time.latest())
    const timeInSeconds = lastestTime2 - lastestTime1

    const leverageMargin2 = precision.mulRate(orderMargin1, leverage)
    const openFee2 = precision.mulRate(leverageMargin2, symbolInfo.config.openFeeRate)
    const initialMargin2 = orderMargin1 - openFee2

    const utilization2 =
      (initialMargin1 * BigInt(9) * BigInt(10 ** 18)) /
      (poolInfo1.baseTokenBalance.amount + poolInfo1.baseTokenBalance.unsettledAmount)

    const cumulativeBorrowingFeePerToken2 =
      ((utilization2 * poolConfig.baseInterestRate) / BigInt(10 ** 18)) * timeInSeconds

    const realizedBorrowingFee2 = (cumulativeBorrowingFeePerToken2 * initialMargin1 * BigInt(10 - 1)) / BigInt(10 ** 18)

    const realizedBorrowingFeeInUsd2 = precision.mulPrice(realizedBorrowingFee2, btcPrice1)

    // position update
    const positionInfo2 = await positionFacet.getSinglePosition(user0.address, btcUsd, wbtcAddr, defaultMarginMode)
    expect(initialMargin2).to.equals(positionInfo2.initialMargin - positionInfo1.initialMargin)
    expect(initialMargin2 * BigInt(25105)).to.equals(
      positionInfo2.initialMarginInUsd - positionInfo1.initialMarginInUsd,
    )
    expect(initialMargin2 * BigInt(10) * BigInt(25105)).to.equals(positionInfo2.qty - positionInfo1.qty)
    const closeFeeInUsd2 = precision.mulRate(positionInfo2.qty, symbolInfo.config.closeFeeRate)
    expect(closeFeeInUsd2).to.equals(positionInfo2.positionFee.closeFeeInUsd)

    expect(cumulativeBorrowingFeePerToken2).to.equals(positionInfo2.positionFee.openBorrowingFeePerToken)
    expect(realizedBorrowingFee2).to.equals(positionInfo2.positionFee.realizedBorrowingFee)
    expect(realizedBorrowingFeeInUsd2).to.equals(positionInfo2.positionFee.realizedBorrowingFeeInUsd)

    // pool update
    const poolInfo2 = await poolFacet.getPool(xBtc)
    expect(cumulativeBorrowingFeePerToken2).to.equals(poolInfo2.borrowingFee.cumulativeBorrowingFeePerToken)
    expect(0).to.equals(poolInfo2.borrowingFee.totalBorrowingFee)
    expect(realizedBorrowingFee2).to.equals(poolInfo2.borrowingFee.totalRealizedBorrowingFee)
    expect(lastestTime2).to.equals(poolInfo2.borrowingFee.lastUpdateTime)

    await time.increase(5 * 60)

    const orderMargin2 = precision.token(3, 17) // 0.3BTC
    const btcPrice2 = precision.price(25010)
    const oracle2 = [{ token: wbtcAddr, minPrice: btcPrice2, maxPrice: btcPrice2 }]

    // user1 add position 1
    await handleOrder(fixture, {
      symbol: btcUsd,
      orderMargin: orderMargin2,
      marginToken: wbtc,
      leverage: leverage,
      oracle: oracle2,
      account: user1,
    })

    const lastestTime3 = BigInt(await time.latest())
    const timeInSeconds3 = lastestTime3 - lastestTime2

    const utilization3 =
      ((initialMargin1 + initialMargin2) * BigInt(9) * BigInt(10 ** 18)) /
      (poolInfo2.baseTokenBalance.amount + poolInfo2.baseTokenBalance.unsettledAmount)

    const cumulativeBorrowingFeePerToken3 =
      cumulativeBorrowingFeePerToken2 +
      ((utilization3 * poolConfig.baseInterestRate) / BigInt(10 ** 18)) * timeInSeconds3

    // user0 position no update
    const positionInfo3 = await positionFacet.getSinglePosition(user0.address, btcUsd, wbtcAddr, defaultMarginMode)
    expect(cumulativeBorrowingFeePerToken2).to.equals(positionInfo3.positionFee.openBorrowingFeePerToken)
    expect(0).to.equals(positionInfo3.positionFee.realizedBorrowingFee - positionInfo2.positionFee.realizedBorrowingFee)
    expect(0).to.equals(
      positionInfo3.positionFee.realizedBorrowingFeeInUsd - positionInfo2.positionFee.realizedBorrowingFeeInUsd,
    )

    // user1 position update
    const positionInfo4 = await positionFacet.getSinglePosition(user1.address, btcUsd, wbtcAddr, defaultMarginMode)
    expect(cumulativeBorrowingFeePerToken3).to.equals(positionInfo4.positionFee.openBorrowingFeePerToken)
    expect(0).to.equals(positionInfo4.positionFee.realizedBorrowingFee)
    expect(0).to.equals(positionInfo4.positionFee.realizedBorrowingFeeInUsd)

    // pool update
    const poolInfo3 = await poolFacet.getPool(xBtc)
    expect(cumulativeBorrowingFeePerToken3).to.equals(poolInfo3.borrowingFee.cumulativeBorrowingFeePerToken)
    expect(0).to.equals(poolInfo3.borrowingFee.totalBorrowingFee)
    expect(realizedBorrowingFee2).to.equals(poolInfo3.borrowingFee.totalRealizedBorrowingFee)
    expect(lastestTime3).to.equals(poolInfo3.borrowingFee.lastUpdateTime)
  })

  it('Case2: Update Borrowing Fee Rate & Charge Borrowing Fee / ETH Short', async function () {
    const symbolInfo = await marketFacet.getSymbol(ethUsd)
    // const config = await configFacet.getConfig()

    const orderMargin0 = precision.token(101, 6) // 101 usdc
    const ethPrice0 = precision.price(1901)
    const usdcPrice0 = precision.price(1)
    const oracle0 = [
      { token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 },
      { token: usdcAddr, minPrice: usdcPrice0, maxPrice: usdcPrice0 },
    ]
    const leverage = precision.rate(10)

    // user0 new position 1
    await handleOrder(fixture, {
      symbol: ethUsd,
      orderMargin: orderMargin0,
      orderSide: OrderSide.SHORT,
      marginToken: usdc,
      leverage: leverage,
      oracle: oracle0,
      account: user0,
    })

    const leverageMargin1 = precision.mulRate(orderMargin0, leverage)
    const openFee1 = precision.mulRate(leverageMargin1, symbolInfo.config.openFeeRate)
    const initialMargin1 = orderMargin0 - openFee1

    // position update
    const defaultMarginMode = false
    const positionInfo1 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(initialMargin1).to.equals(positionInfo1.initialMargin)
    expect(initialMargin1 * BigInt(9)).to.equals(positionInfo1.holdPoolAmount)

    const closeFeeInUsd1 = precision.mulRate(positionInfo1.qty, symbolInfo.config.closeFeeRate)
    expect(closeFeeInUsd1).to.equals(positionInfo1.positionFee.closeFeeInUsd)
    expect(0).to.equals(positionInfo1.positionFee.openBorrowingFeePerToken)
    expect(0).to.equals(positionInfo1.positionFee.realizedBorrowingFee)
    expect(0).to.equals(positionInfo1.positionFee.realizedBorrowingFeeInUsd)

    // pool update
    const poolInfo1 = await poolFacet.getUsdPool()
    expect(0).to.equals(pool.getUsdPoolBorrowingFee(poolInfo1, usdcAddr)?.cumulativeBorrowingFeePerToken)
    expect(0).to.equals(pool.getUsdPoolBorrowingFee(poolInfo1, usdcAddr)?.totalBorrowingFee)
    expect(0).to.equals(pool.getUsdPoolBorrowingFee(poolInfo1, usdcAddr)?.totalRealizedBorrowingFee)
    const lastestTime1 = BigInt(await time.latest())
    expect(lastestTime1).to.equals(pool.getUsdPoolBorrowingFee(poolInfo1, usdcAddr)?.lastUpdateTime)
    expect(initialMargin1 * BigInt(9)).to.equals(pool.getUsdPoolStableTokenHoldAmount(poolInfo1, usdcAddr))

    await time.increase(7 * 60 * 60)

    const orderMargin1 = precision.token(66, 6) // 66 usdc
    const ethPrice1 = precision.price(1902)
    const usdcPrice1 = precision.price(99, 6)
    const oracle1 = [
      { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
      { token: usdcAddr, minPrice: usdcPrice1, maxPrice: usdcPrice1 },
    ]
    // user0 add position 2
    await handleOrder(fixture, {
      symbol: ethUsd,
      orderMargin: orderMargin1,
      orderSide: OrderSide.SHORT,
      marginToken: usdc,
      leverage: leverage,
      oracle: oracle1,
      account: user0,
    })

    const lastestTime2 = BigInt(await time.latest())
    const timeInSeconds = lastestTime2 - lastestTime1

    const leverageMargin2 = precision.mulRate(orderMargin1, leverage)
    const openFee2 = precision.mulRate(leverageMargin2, symbolInfo.config.openFeeRate)
    const initialMargin2 = orderMargin1 - openFee2

    const utilization2 =
      (initialMargin1 * BigInt(9) * BigInt(10 ** 18)) /
      (pool.getUsdPoolStableTokenAmount(poolInfo1, usdcAddr) +
        pool.getUsdPoolStableTokenUnsettledAmount(poolInfo1, usdcAddr))

    // config
    const usdPoolConfig = await configFacet.getUsdPoolConfig()

    const cumulativeBorrowingFeePerToken2 =
      ((utilization2 * configUtils.getUsdPoolBorrowingBaseInterest(usdPoolConfig, usdcAddr)) / BigInt(10 ** 18)) *
      timeInSeconds

    const realizedBorrowingFee2 = (cumulativeBorrowingFeePerToken2 * initialMargin1 * BigInt(10 - 1)) / BigInt(10 ** 18)

    const realizedBorrowingFeeInUsd2 = precision.mulPrice(realizedBorrowingFee2 * BigInt(10 ** 12), usdcPrice1)

    // position update
    const positionInfo2 = await positionFacet.getSinglePosition(user0.address, ethUsd, usdcAddr, defaultMarginMode)
    expect(initialMargin2).to.equals(positionInfo2.initialMargin - positionInfo1.initialMargin)
    const closeFeeInUsd2 = precision.mulRate(positionInfo2.qty, symbolInfo.config.closeFeeRate)
    expect(closeFeeInUsd2).to.equals(positionInfo2.positionFee.closeFeeInUsd)

    expect(cumulativeBorrowingFeePerToken2).to.equals(positionInfo2.positionFee.openBorrowingFeePerToken)
    expect(realizedBorrowingFee2).to.equals(positionInfo2.positionFee.realizedBorrowingFee)
    expect(realizedBorrowingFeeInUsd2).to.equals(positionInfo2.positionFee.realizedBorrowingFeeInUsd)

    // pool update
    const poolInfo2 = await poolFacet.getUsdPool()
    expect(cumulativeBorrowingFeePerToken2).to.equals(
      pool.getUsdPoolBorrowingFee(poolInfo2, usdcAddr)?.cumulativeBorrowingFeePerToken,
    )
    expect(0).to.equals(pool.getUsdPoolBorrowingFee(poolInfo2, usdcAddr)?.totalBorrowingFee)
    expect(realizedBorrowingFee2).to.equals(pool.getUsdPoolBorrowingFee(poolInfo2, usdcAddr)?.totalRealizedBorrowingFee)
    expect(lastestTime2).to.equals(pool.getUsdPoolBorrowingFee(poolInfo2, usdcAddr)?.lastUpdateTime)
  })
})
