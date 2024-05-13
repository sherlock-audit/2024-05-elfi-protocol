// import { expect } from 'chai'
// import { Fixture, deployFixture } from '@test/deployFixture'
// import { precision } from '@utils/precision'
// import { handleMint } from '@utils/mint'
// import {
//   AccountFacet,
//   ConfigFacet,
//   MarketFacet,
//   MockToken,
//   PoolFacet,
//   PositionFacet,
//   RebalanceFacet,
//   SwapFacet,
//   TradeVault,
//   VaultFacet,
// } from 'types'
// import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
// import { handleOrder } from '@utils/order'
// import { OrderSide, PositionSide } from '@utils/constants'
// import { deposit } from '@utils/deposit'
// import { createPool, deployUniswapV3 } from '@utils/uniswap'
// import { ethers } from 'hardhat'
// import exp from 'constants'
// import { pool } from '@utils/pool'
// import { oracles } from '@utils/oracles'
// import { account } from '@utils/account'

// describe('Rebalance Test', function () {
//   let fixture: Fixture
//   let tradeVault: TradeVault,
//     marketFacet: MarketFacet,
//     accountFacet: AccountFacet,
//     positionFacet: PositionFacet,
//     vaultFacet: VaultFacet,
//     swapFacet: SwapFacet,
//     configFacet: ConfigFacet,
//     poolFacet: PoolFacet,
//     rebalanceFacet: RebalanceFacet

//   let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner, user3: HardhatEthersSigner
//   let diamondAddr: string,
//     portfolioAddress: string,
//     wbtcAddr: string,
//     wethAddr: string,
//     solAddr: string,
//     usdcAddr: string
//   let btcUsd: string, ethUsd: string, solUsd: string, xBtc: string, xEth: string, xSol: string, xUsd: string
//   let wbtc: MockToken, weth: MockToken, sol: MockToken, usdc: MockToken

//   beforeEach(async () => {
//     fixture = await deployFixture()
//     ;({
//       tradeVault,
//       marketFacet,
//       accountFacet,
//       positionFacet,
//       vaultFacet,
//       swapFacet,
//       configFacet,
//       poolFacet,
//       rebalanceFacet,
//     } = fixture.contracts)
//     ;({ user0, user1, user2, user3 } = fixture.accounts)
//     ;({ btcUsd, ethUsd, solUsd } = fixture.symbols)
//     ;({ xBtc, xEth, xSol, xUsd } = fixture.pools)
//     ;({ wbtc, weth, sol, usdc } = fixture.tokens)
//     ;({ diamondAddr } = fixture.addresses)
//     wbtcAddr = await wbtc.getAddress()
//     wethAddr = await weth.getAddress()
//     solAddr = await sol.getAddress()
//     usdcAddr = await usdc.getAddress()
//     portfolioAddress = await vaultFacet.getPortfolioVaultAddress()

//     const btcTokenPrice = precision.price(65000)
//     const btcOracle = [{ token: wbtcAddr, minPrice: btcTokenPrice, maxPrice: btcTokenPrice }]
//     await handleMint(fixture, {
//       stakeToken: xBtc,
//       requestToken: wbtc,
//       requestTokenAmount: precision.token(100),
//       oracle: btcOracle,
//     })
//     const ethTokenPrice = precision.price(3600)
//     const ethOracle = [{ token: wethAddr, minPrice: ethTokenPrice, maxPrice: ethTokenPrice }]
//     await handleMint(fixture, {
//       requestTokenAmount: precision.token(1000),
//       oracle: ethOracle,
//     })

//     const solTokenPrice = precision.price(160)
//     const solOracle = [{ token: solAddr, minPrice: solTokenPrice, maxPrice: solTokenPrice }]
//     await handleMint(fixture, {
//       stakeToken: xSol,
//       requestToken: sol,
//       requestTokenAmount: precision.token(10000, 9),
//       oracle: solOracle,
//     })
//     const usdcTokenPrice = precision.price(101, 6)
//     const usdOracle = [{ token: usdcAddr, minPrice: usdcTokenPrice, maxPrice: usdcTokenPrice }]

//     await handleMint(fixture, {
//       requestTokenAmount: precision.token(100_000, 6),
//       stakeToken: xUsd,
//       requestToken: usdc,
//       oracle: usdOracle,
//     })
//   })

//   it('Case0: Rebalance0', async function () {
    
//     const user0DepositSolAmount = precision.token(100, 9)

//     await deposit(fixture, {
//       account: user0,
//       token: sol,
//       amount: user0DepositSolAmount,
//     })

//     const user1DepositUsdcAmount = precision.token(10000, 6)
//     await deposit(fixture, {
//       account: user1,
//       token: usdc,
//       amount: user1DepositUsdcAmount,
//     })

//     const user2DepositUsdcAmount = precision.token(15000, 6)
//     await deposit(fixture, {
//       account: user2,
//       token: usdc,
//       amount: user2DepositUsdcAmount,
//     })

//     const user0OrderMarginInUsd0 = precision.usd(9999)
//     const user1OrderMarginInUsd0 = precision.usd(8000)
//     const user2OrderMarginInUsd0 = precision.usd(4000)
//     const solPrice0 = precision.price(150)
//     const usdcPrice0 = precision.price(1)
//     const ethPrice0 = precision.price(3200)
//     const oracle0 = [
//       { token: solAddr, minPrice: solPrice0, maxPrice: solPrice0 },
//       { token: usdcAddr, minPrice: usdcPrice0, maxPrice: usdcPrice0 },
//       { token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 },
//     ]

//     await handleOrder(fixture, {
//       account: user0,
//       orderMargin: user0OrderMarginInUsd0,
//       marginToken: usdc,
//       symbol: solUsd,
//       orderSide: OrderSide.SHORT,
//       oracle: oracle0,
//       isCrossMargin: true,
//       leverage: precision.rate(7),
//     })

//     await handleOrder(fixture, {
//       account: user1,
//       orderMargin: user1OrderMarginInUsd0,
//       marginToken: weth,
//       symbol: ethUsd,
//       oracle: oracle0,
//       isCrossMargin: true,
//       leverage: precision.rate(19),
//     })

//     await handleOrder(fixture, {
//       account: user2,
//       orderMargin: user2OrderMarginInUsd0,
//       marginToken: sol,
//       symbol: solUsd,
//       oracle: oracle0,
//       isCrossMargin: true,
//       leverage: precision.rate(15),
//     })

//     const user0SolShortPositionInfo0 = await positionFacet.getSinglePosition(user0.address, solUsd, usdcAddr, true)
//     const user1EthLongPositionInfo0 = await positionFacet.getSinglePosition(user1.address, ethUsd, wethAddr, true)
//     const user2SolLongPositionInfo0 = await positionFacet.getSinglePosition(user2.address, solUsd, solAddr, true)

//     const solPrice1 = solPrice0 - precision.price(10)
//     const usdcPrice1 = usdcPrice0
//     const ethPrice1 = ethPrice0
//     const oracle1 = [
//       { token: solAddr, minPrice: solPrice1, maxPrice: solPrice1 },
//       { token: usdcAddr, minPrice: usdcPrice1, maxPrice: usdcPrice1 },
//       { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
//     ]

//     await handleOrder(fixture, {
//       account: user0,
//       symbol: solUsd,
//       orderSide: OrderSide.LONG,
//       posSide: PositionSide.DECREASE,
//       marginToken: usdc,
//       isCrossMargin: true,
//       qty: user0SolShortPositionInfo0.qty,
//       oracle: oracle1,
//     })

//     const solPrice2 = solPrice1 - precision.price(10)
//     const usdcPrice2 = usdcPrice1
//     const ethPrice2 = ethPrice1 - precision.price(100)
//     const oracle2 = [
//       { token: solAddr, minPrice: solPrice2, maxPrice: solPrice2 },
//       { token: usdcAddr, minPrice: usdcPrice2, maxPrice: usdcPrice2 },
//       { token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 },
//     ]

//     await handleOrder(fixture, {
//       account: user1,
//       symbol: ethUsd,
//       orderSide: OrderSide.SHORT,
//       posSide: PositionSide.DECREASE,
//       marginToken: weth,
//       isCrossMargin: true,
//       qty: user1EthLongPositionInfo0.qty,
//       oracle: oracle2,
//     })

//     await handleOrder(fixture, {
//       account: user2,
//       symbol: solUsd,
//       orderSide: OrderSide.SHORT,
//       posSide: PositionSide.DECREASE,
//       marginToken: sol,
//       isCrossMargin: true,
//       qty: user2SolLongPositionInfo0.qty,
//       oracle: oracle2,
//     })

//     // pre rebalance
//     const ethPool0 = await poolFacet.getPool(xEth)
//     const solPool0 = await poolFacet.getPool(xSol)
//     const usdPool0 = await poolFacet.getUsdPool()

//     console.log('usdPool0 usdc amount', pool.getUsdPoolStableTokenAmount(usdPool0, usdcAddr))
//     console.log('usdPool0 usdc unsettledAmount', pool.getUsdPoolStableTokenUnsettledAmount(usdPool0, usdcAddr))
//     console.log('solPool0 usdc lossAmount', pool.getPoolStableTokenLossAmount(solPool0, usdcAddr))
//     console.log('solPool0 usdc amount', pool.getPoolStableTokenAmount(solPool0, usdcAddr))
//     console.log('solPool0 usdc unsettleAmount', pool.getPoolStableTokenUnsettledAmount(solPool0, usdcAddr))
//     console.log('solPool0 sol unsettleAmount', solPool0.baseTokenBalance.unsettledAmount)
//     console.log('solPool0 sol amount', solPool0.baseTokenBalance.amount)
//     console.log('ethPool0 weth unsettleAmount', ethPool0.baseTokenBalance.unsettledAmount)
//     console.log('ethPool0 weth amount', ethPool0.baseTokenBalance.amount)

//     const account0Info0 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle2))
//     const account1Info0 = await accountFacet.getAccountInfoWithOracles(user1.address, oracles.format(oracle2))
//     const account2Info0 = await accountFacet.getAccountInfoWithOracles(user2.address, oracles.format(oracle2))

//     const user3DepositSolAmount = precision.token(70, 9)
//     await deposit(fixture, {
//       account: user3,
//       token: sol,
//       amount: user3DepositSolAmount,
//     })

//     const solPortfolioVault0 = await sol.balanceOf(portfolioAddress)
//     const usdcPortfolioVault0 = await usdc.balanceOf(portfolioAddress)
//     const ethPortfolioVault0 = await weth.balanceOf(portfolioAddress)
//     const usdcSolVault0 = await usdc.balanceOf(xSol)

//     const [deployer] = await ethers.getSigners()
//     const [factoryAddr, weth9Addr, routerAddr, nftPositionManagerAddr] = await deployUniswapV3(deployer)
//     await configFacet.setUniswapRouter(routerAddr)
//     await createPool(deployer, factoryAddr, nftPositionManagerAddr, sol, usdc, Number(solPrice2 / precision.price(1)))
//     await createPool(deployer, factoryAddr, nftPositionManagerAddr, weth, usdc, Number(ethPrice2 / precision.price(1)))

//     console.log("usdcSolVault0", usdcSolVault0)
//     console.log("usdcPortfolioVault0", usdcPortfolioVault0)

//     await rebalanceFacet.autoRebalance(oracles.format(oracle2))

//     const ethPool1 = await poolFacet.getPool(xEth)
//     const solPool1 = await poolFacet.getPool(xSol)
//     const usdPool1 = await poolFacet.getUsdPool()

//     const account0Info1 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle2))
//     const account1Info1 = await accountFacet.getAccountInfoWithOracles(user1.address, oracles.format(oracle2))
//     const account2Info1 = await accountFacet.getAccountInfoWithOracles(user2.address, oracles.format(oracle2))

//     expect(0).to.be.equals(pool.getUsdPoolStableTokenUnsettledAmount(usdPool1, usdcAddr))
//     expect(pool.getUsdPoolStableTokenAmount(usdPool1, usdcAddr)).to.be.equals(
//       pool.getUsdPoolStableTokenUnsettledAmount(usdPool0, usdcAddr) +
//         pool.getUsdPoolStableTokenAmount(usdPool0, usdcAddr),
//     )

//     expect(0).to.be.equals(pool.getPoolStableTokenAmount(ethPool1, usdcAddr))
//     expect(0).to.be.equals(pool.getPoolStableTokenUnsettledAmount(ethPool1, usdcAddr))

//     expect(0).to.be.equals(pool.getPoolStableTokenUnsettledAmount(solPool1, usdcAddr))

//     const solPortfolioVault1 = await sol.balanceOf(portfolioAddress)
//     const usdcPortfolioVault1 = await usdc.balanceOf(portfolioAddress)
//     const ethPortfolioVault1 = await weth.balanceOf(portfolioAddress)

//     console.log('usdPool1 usdc amount', pool.getUsdPoolStableTokenAmount(usdPool1, usdcAddr))
//     console.log('usdPool1 usdc unsettledAmount', pool.getUsdPoolStableTokenUnsettledAmount(usdPool1, usdcAddr))
//     console.log('solPool1 usdc lossAmount', pool.getPoolStableTokenLossAmount(solPool1, usdcAddr))
//     console.log('solPool1 sol unsettleAmount', solPool1.baseTokenBalance.unsettledAmount)
//     console.log('solPool1 sol amount', solPool1.baseTokenBalance.amount)
//     console.log('ethPool1 weth unsettleAmount', ethPool1.baseTokenBalance.unsettledAmount)
//     console.log('ethPool1 weth amount', ethPool1.baseTokenBalance.amount)

//     console.log('user2 sol liability0', account.getAccountTokenLiability(account2Info1, solAddr))

//     // const user2DepositSolAmount = precision.token(60, 9)
//     // await deposit(fixture, {
//     //   account: user2,
//     //   token: sol,
//     //   amount: user2DepositSolAmount,
//     // })

//     // const account0Info2 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle2))
//     // const account1Info2 = await accountFacet.getAccountInfoWithOracles(user1.address, oracles.format(oracle2))
//     // const account2Info2 = await accountFacet.getAccountInfoWithOracles(user2.address, oracles.format(oracle2))

//     // console.log('user2 sol liability1', account.getAccountTokenLiability(account2Info2, solAddr))

//     // await rebalanceFacet.autoRebalance(oracles.format(oracle2))

//     // const ethPool2 = await poolFacet.getPool(xEth)
//     // const solPool2 = await poolFacet.getPool(xSol)
//     // const usdPool2 = await poolFacet.getUsdPool()

//     // console.log('usdPool2 usdc amount', pool.getUsdPoolStableTokenAmount(usdPool2, usdcAddr))
//     // console.log('usdPool2 usdc unsettledAmount', pool.getUsdPoolStableTokenUnsettledAmount(usdPool2, usdcAddr))
//     // console.log('solPool2 usdc lossAmount', pool.getPoolStableTokenLossAmount(solPool2, usdcAddr))
//     // console.log('solPool2 sol unsettleAmount', solPool2.baseTokenBalance.unsettledAmount)
//     // console.log('solPool2 sol amount', solPool2.baseTokenBalance.amount)
//     // console.log('ethPool2 weth unsettleAmount', ethPool2.baseTokenBalance.unsettledAmount)
//     // console.log('ethPool2 weth amount', ethPool2.baseTokenBalance.amount)
//   })

//   it('Case1: Rebalance1', async function () {
//     const user0DepositBtcAmount = precision.token(1, 17)
//     await deposit(fixture, {
//       account: user0,
//       token: wbtc,
//       amount: user0DepositBtcAmount,
//     })

//     const user0DepositEthAmount = precision.token(1)
//     await deposit(fixture, {
//       account: user0,
//       token: weth,
//       amount: user0DepositEthAmount,
//     })

//     const user1DepositEthAmount = precision.token(1)
//     await deposit(fixture, {
//       account: user1,
//       token: weth,
//       amount: user1DepositEthAmount,
//     })

//     const btcPrice0 = precision.price(64000)
//     const solPrice0 = precision.price(150)
//     const usdcPrice0 = precision.price(99, 6)
//     const ethPrice0 = precision.price(3200)

//     const oracle0 = [
//       { token: wbtcAddr, minPrice: btcPrice0, maxPrice: btcPrice0 },
//       { token: solAddr, minPrice: solPrice0, maxPrice: solPrice0 },
//       { token: usdcAddr, minPrice: usdcPrice0, maxPrice: usdcPrice0 },
//       { token: wethAddr, minPrice: ethPrice0, maxPrice: ethPrice0 },
//     ]

//     await handleOrder(fixture, {
//       account: user0,
//       orderMargin: precision.usd(2000),
//       marginToken: usdc,
//       symbol: solUsd,
//       orderSide: OrderSide.SHORT,
//       oracle: oracle0,
//       isCrossMargin: true,
//       leverage: precision.rate(10),
//     })

//     await handleOrder(fixture, {
//       account: user0,
//       orderMargin: precision.usd(1000),
//       marginToken: weth,
//       symbol: ethUsd,
//       orderSide: OrderSide.LONG,
//       oracle: oracle0,
//       isCrossMargin: true,
//       leverage: precision.rate(20),
//     })

//     await handleOrder(fixture, {
//       account: user0,
//       orderMargin: precision.token(1000, 6),
//       marginToken: usdc,
//       symbol: ethUsd,
//       orderSide: OrderSide.SHORT,
//       oracle: oracle0,
//       isCrossMargin: false,
//       leverage: precision.rate(10),
//     })

//     await handleOrder(fixture, {
//       account: user1,
//       orderMargin: precision.token(500, 6),
//       marginToken: usdc,
//       symbol: solUsd,
//       oracle: oracle0,
//       orderSide: OrderSide.SHORT,
//       isCrossMargin: false,
//       leverage: precision.rate(19),
//     })

//     await handleOrder(fixture, {
//       account: user1,
//       orderMargin: precision.usd(800),
//       marginToken: usdc,
//       symbol: solUsd,
//       oracle: oracle0,
//       orderSide: OrderSide.SHORT,
//       isCrossMargin: true,
//       leverage: precision.rate(20),
//     })

//     await handleOrder(fixture, {
//       account: user1,
//       orderMargin: precision.usd(1500),
//       marginToken: usdc,
//       symbol: ethUsd,
//       oracle: oracle0,
//       orderSide: OrderSide.SHORT,
//       isCrossMargin: true,
//       leverage: precision.rate(20),
//     })

//     const user0SolShortPositionInfo0 = await positionFacet.getSinglePosition(user0.address, solUsd, usdcAddr, true)
//     const user0EthLongPositionInfo0 = await positionFacet.getSinglePosition(user0.address, ethUsd, wethAddr, true)
//     const user0EthShortIsolatePositionInfo0 = await positionFacet.getSinglePosition(
//       user0.address,
//       ethUsd,
//       usdcAddr,
//       false,
//     )

//     const user1SolShortIsolatePositionInfo0 = await positionFacet.getSinglePosition(
//       user1.address,
//       solUsd,
//       usdcAddr,
//       false,
//     )
//     const user1SolShortPositionInfo0 = await positionFacet.getSinglePosition(user1.address, solUsd, usdcAddr, true)
//     const user1EthShortPositionInfo0 = await positionFacet.getSinglePosition(user1.address, ethUsd, usdcAddr, true)

//     const btcPrice1 = btcPrice0
//     const solPrice1 = solPrice0 - precision.price(5)
//     const usdcPrice1 = usdcPrice0
//     const ethPrice1 = ethPrice0 + precision.price(30)
//     const oracle1 = [
//       { token: wbtcAddr, minPrice: btcPrice1, maxPrice: btcPrice1 },
//       { token: solAddr, minPrice: solPrice1, maxPrice: solPrice1 },
//       { token: usdcAddr, minPrice: usdcPrice1, maxPrice: usdcPrice1 },
//       { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
//     ]

//     await handleOrder(fixture, {
//       account: user0,
//       symbol: ethUsd,
//       orderSide: OrderSide.LONG,
//       posSide: PositionSide.DECREASE,
//       marginToken: usdc,
//       isCrossMargin: false,
//       qty: user0EthShortIsolatePositionInfo0.qty,
//       oracle: oracle1,
//     })

//     await handleOrder(fixture, {
//       account: user0,
//       symbol: solUsd,
//       orderSide: OrderSide.LONG,
//       posSide: PositionSide.DECREASE,
//       marginToken: usdc,
//       isCrossMargin: true,
//       qty: user0SolShortPositionInfo0.qty,
//       oracle: oracle1,
//     })

//     const btcPrice2 = btcPrice1
//     const solPrice2 = solPrice0 + precision.price(5)
//     const usdcPrice2 = usdcPrice1
//     const ethPrice2 = ethPrice0 - precision.price(20)
//     const oracle2 = [
//       { token: wbtcAddr, minPrice: btcPrice2, maxPrice: btcPrice2 },
//       { token: solAddr, minPrice: solPrice2, maxPrice: solPrice2 },
//       { token: usdcAddr, minPrice: usdcPrice2, maxPrice: usdcPrice2 },
//       { token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 },
//     ]

//     await handleOrder(fixture, {
//       account: user0,
//       symbol: ethUsd,
//       orderSide: OrderSide.SHORT,
//       posSide: PositionSide.DECREASE,
//       marginToken: weth,
//       isCrossMargin: true,
//       qty: user0EthLongPositionInfo0.qty,
//       oracle: oracle2,
//     })

//     await handleOrder(fixture, {
//       account: user1,
//       symbol: solUsd,
//       orderSide: OrderSide.LONG,
//       posSide: PositionSide.DECREASE,
//       marginToken: usdc,
//       isCrossMargin: true,
//       qty: user1SolShortPositionInfo0.qty,
//       oracle: oracle2,
//     })

//     await handleOrder(fixture, {
//       account: user1,
//       symbol: solUsd,
//       orderSide: OrderSide.LONG,
//       posSide: PositionSide.DECREASE,
//       marginToken: usdc,
//       isCrossMargin: false,
//       qty: user1SolShortIsolatePositionInfo0.qty,
//       oracle: oracle2,
//     })

//     await handleOrder(fixture, {
//       account: user1,
//       symbol: ethUsd,
//       orderSide: OrderSide.LONG,
//       posSide: PositionSide.DECREASE,
//       marginToken: usdc,
//       isCrossMargin: true,
//       qty: user1EthShortPositionInfo0.qty,
//       oracle: oracle2,
//     })

//     // pre rebalance
//     const ethPool0 = await poolFacet.getPool(xEth)
//     const solPool0 = await poolFacet.getPool(xSol)
//     const usdPool0 = await poolFacet.getUsdPool()

//     console.log('usdPool0 usdc amount', pool.getUsdPoolStableTokenAmount(usdPool0, usdcAddr))
//     console.log('usdPool0 usdc unsettledAmount', pool.getUsdPoolStableTokenUnsettledAmount(usdPool0, usdcAddr))
//     console.log('solPool0 usdc amount', pool.getPoolStableTokenAmount(solPool0, usdcAddr))
//     console.log('solPool0 usdc lossAmount', pool.getPoolStableTokenLossAmount(solPool0, usdcAddr))
//     console.log('solPool0 sol unsettleAmount', solPool0.baseTokenBalance.unsettledAmount)
//     console.log('solPool0 sol amount', solPool0.baseTokenBalance.amount)
//     console.log('ethPool0 usdc amount', pool.getPoolStableTokenAmount(ethPool0, usdcAddr))
//     console.log('ethPool0 usdc lossAmount', pool.getPoolStableTokenLossAmount(ethPool0, usdcAddr))
//     console.log('ethPool0 weth unsettleAmount', ethPool0.baseTokenBalance.unsettledAmount)
//     console.log('ethPool0 weth amount', ethPool0.baseTokenBalance.amount)

//     const account0Info0 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle2))
//     const account1Info0 = await accountFacet.getAccountInfoWithOracles(user1.address, oracles.format(oracle2))
//     const account2Info0 = await accountFacet.getAccountInfoWithOracles(user2.address, oracles.format(oracle2))

//     const user3DepositSolAmount = precision.token(70, 9)
//     await deposit(fixture, {
//       account: user3,
//       token: sol,
//       amount: user3DepositSolAmount,
//     })

//     const solPortfolioVault0 = await sol.balanceOf(portfolioAddress)
//     const usdcPortfolioVault0 = await usdc.balanceOf(portfolioAddress)
//     const ethPortfolioVault0 = await weth.balanceOf(portfolioAddress)


//     const [deployer] = await ethers.getSigners()
//     const [factoryAddr, weth9Addr, routerAddr, nftPositionManagerAddr] = await deployUniswapV3(deployer)
//     await configFacet.setUniswapRouter(routerAddr)
//     await createPool(deployer, factoryAddr, nftPositionManagerAddr, sol, usdc, Number(solPrice2 / precision.price(1)))
//     await createPool(deployer, factoryAddr, nftPositionManagerAddr, weth, usdc, Number(ethPrice2 / precision.price(1)))
//     await createPool(deployer, factoryAddr, nftPositionManagerAddr, wbtc, usdc, Number(btcPrice2 / precision.price(1)))

//     await rebalanceFacet.autoRebalance(oracles.format(oracle2))

//     const ethPool1 = await poolFacet.getPool(xEth)
//     const solPool1 = await poolFacet.getPool(xSol)
//     const usdPool1 = await poolFacet.getUsdPool()

//     const account0Info1 = await accountFacet.getAccountInfoWithOracles(user0.address, oracles.format(oracle2))
//     const account1Info1 = await accountFacet.getAccountInfoWithOracles(user1.address, oracles.format(oracle2))
//     const account2Info1 = await accountFacet.getAccountInfoWithOracles(user2.address, oracles.format(oracle2))

//     expect(0).to.be.equals(pool.getUsdPoolStableTokenUnsettledAmount(usdPool1, usdcAddr))
//     expect(pool.getUsdPoolStableTokenAmount(usdPool1, usdcAddr)).to.be.equals(
//       pool.getUsdPoolStableTokenUnsettledAmount(usdPool0, usdcAddr) +
//         pool.getUsdPoolStableTokenAmount(usdPool0, usdcAddr),
//     )

//     expect(0).to.be.equals(pool.getPoolStableTokenAmount(ethPool1, usdcAddr))
//     expect(0).to.be.equals(pool.getPoolStableTokenLossAmount(ethPool1, usdcAddr))

//     expect(0).to.be.equals(pool.getPoolStableTokenAmount(solPool1, usdcAddr))
//     expect(0).to.be.equals(pool.getPoolStableTokenLossAmount(solPool1, usdcAddr))

//     const solPortfolioVault1 = await sol.balanceOf(portfolioAddress)
//     const usdcPortfolioVault1 = await usdc.balanceOf(portfolioAddress)
//     const ethPortfolioVault1 = await weth.balanceOf(portfolioAddress)

//     console.log('usdPool1 usdc amount', pool.getUsdPoolStableTokenAmount(usdPool1, usdcAddr))
//     console.log('usdPool1 usdc unsettledAmount', pool.getUsdPoolStableTokenUnsettledAmount(usdPool1, usdcAddr))
//     console.log('solPool1 usdc amount', pool.getPoolStableTokenAmount(solPool1, usdcAddr))
//     console.log('solPool1 usdc lossAmount', pool.getPoolStableTokenLossAmount(solPool1, usdcAddr))
//     console.log('solPool1 sol unsettleAmount', solPool1.baseTokenBalance.unsettledAmount)
//     console.log('solPool1 sol amount', solPool1.baseTokenBalance.amount)
//     console.log('ethPool1 usdc amount', pool.getPoolStableTokenAmount(ethPool1, usdcAddr))
//     console.log('ethPool1 usdc lossAmount', pool.getPoolStableTokenLossAmount(ethPool1, usdcAddr))
//     console.log('ethPool1 weth unsettleAmount', ethPool1.baseTokenBalance.unsettledAmount)
//     console.log('ethPool1 weth amount', ethPool1.baseTokenBalance.amount)

//   })
// })
