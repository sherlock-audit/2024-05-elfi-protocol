import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { MINT_ID_KEY } from '@utils/constants'
import { precision } from '@utils/precision'
import { createMint, createMintWrapper, executeMint, handleMint } from '@utils/mint'
import {
  ConfigProcess,
  FeeFacet,
  MarketFacet,
  MockToken,
  PoolFacet,
  StakeFacet,
  StakingAccountFacet,
  WETH,
} from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'
import { configs } from '@utils/configs'
import { oracles } from '@utils/oracles'
import { ConfigFacet, IConfig } from 'types/contracts/facets/ConfigFacet'

describe('Mint xToken Test', function () {
  let fixture: Fixture
  let marketFacet: MarketFacet,
    poolFacet: PoolFacet,
    stakeFacet: StakeFacet,
    stakingAccountFacet: StakingAccountFacet,
    feeFacet: FeeFacet,
    configFacet: ConfigFacet
  let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner, user3: HardhatEthersSigner
  let lpVaultAddr: string, portfolioVaultAddr: string, wbtcAddr: string, wethAddr: string, linkAddr: string
  let xBtc: string, xEth: string, xEthSol: string
  let wbtc: MockToken, weth: WETH, link: MockToken
  let config: IConfig.CommonConfigParamsStructOutput

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ marketFacet, poolFacet, stakeFacet, stakingAccountFacet, feeFacet, configFacet } = fixture.contracts)
    ;({ user0, user1, user2, user3 } = fixture.accounts)
    ;({ xBtc, xEth } = fixture.pools)
    ;({ wbtc, weth } = fixture.tokens)
    ;({ lpVaultAddr, portfolioVaultAddr } = fixture.addresses)

    config = await configFacet.getConfig()
    wethAddr = await weth.getAddress()
    wbtcAddr = await wbtc.getAddress()
  })

  it('Case0: Mint Errors', async function () {
    // requestTokenAmount zero
    await expect(createMintWrapper(fixture, { stakeToken: xEth, requestTokenAmount: 0 })).to.be.reverted

    // mint token error
    await expect(
      createMintWrapper(fixture, { stakeToken: xEth, requestToken: wbtc, requestTokenAmount: precision.token(100) }),
    ).to.be.reverted

    // collateral token error
    await expect(
      createMintWrapper(fixture, {
        stakeToken: xEth,
        requestToken: wbtc,
        requestTokenAmount: precision.token(100),
        isCollateral: true,
      }),
    ).to.be.reverted

    // stake pool zero
    await expect(
      createMintWrapper(fixture, { stakeToken: ethers.ZeroAddress, requestTokenAmount: precision.token(100) }),
    ).to.be.reverted

    // stake pool not exists
    await expect(
      createMintWrapper(fixture, { stakeToken: await weth.getAddress(), requestTokenAmount: precision.token(100) }),
    ).to.be.reverted

    // request id not exists
    await createMint(fixture, { requestTokenAmount: precision.token(100) })

    const requestId = await marketFacet.getLastUuid(MINT_ID_KEY)

    const requestTokenAddr = await weth.getAddress()
    const tokenPrice = precision.price(1800)

    await expect(
      stakeFacet.executeMintStakeToken(0, [
        { token: requestTokenAddr, targetToken: ethers.ZeroAddress, minPrice: tokenPrice, maxPrice: tokenPrice },
      ]),
    ).to.be.reverted

    await expect(
      stakeFacet.executeMintStakeToken(BigInt(requestId) + BigInt(1), [
        { token: requestTokenAddr, targetToken: ethers.ZeroAddress, minPrice: tokenPrice, maxPrice: tokenPrice },
      ]),
    ).to.be.reverted

    // stake amount too small
    const decimals = await weth.decimals()
    await createMint(fixture, {
      requestTokenAmount:
        BigInt(config.stakeConfig.minPrecisionMultiple) *
          BigInt(BigInt(10) ** BigInt(decimals - BigInt(configs.getTradeTokenPrecision(config, wethAddr)))) -
        BigInt(1),
    })
    const requestId1 = await marketFacet.getLastUuid(MINT_ID_KEY)
    await expect(
      stakeFacet.executeMintStakeToken(BigInt(requestId1), [
        { token: requestTokenAddr, targetToken: ethers.ZeroAddress, minPrice: tokenPrice, maxPrice: tokenPrice },
      ]),
    ).to.be.reverted
  })

  it('Case1: Mint xBtc with WBTC Success', async function () {
    const preBalance = BigInt(await wbtc.balanceOf(user0.address))
    const preVaultBalance = BigInt(await wbtc.balanceOf(lpVaultAddr))
    const preMarketBalance = BigInt(await wbtc.balanceOf(xBtc))

    const preEthTokenBalance = BigInt(await ethers.provider.getBalance(user0.address))
    const preEthVaultBalance = BigInt(await weth.balanceOf(portfolioVaultAddr))

    const requestTokenAmount = precision.token(1, 17) //0.1BTC
    const tokenPrice = precision.price(25000)
    const executionFee = precision.token(2, 15)

    await createMint(fixture, {
      receiver: user0.address,
      stakeToken: xBtc,
      requestToken: wbtc,
      requestTokenAmount: requestTokenAmount,
      walletRequestTokenAmount: requestTokenAmount,
      minStakeAmount: precision.token(90, 15), //0.09xBtc
      isCollateral: false,
      isNativeToken: false,
      executionFee: executionFee,
    })

    const nextBalance = BigInt(await wbtc.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await wbtc.balanceOf(lpVaultAddr))

    const nextEthTokenBalance = BigInt(await ethers.provider.getBalance(user0.address))
    const nextEthVaultBalance = BigInt(await weth.balanceOf(portfolioVaultAddr))

    // wallet
    expect(requestTokenAmount).to.equals(preBalance - nextBalance)
    expect(requestTokenAmount).to.equals(nextVaultBalance - preVaultBalance)

    expect(executionFee).to.be.lessThan(preEthTokenBalance - nextEthTokenBalance)
    expect(executionFee).to.equals(nextEthVaultBalance - preEthVaultBalance)

    const xToken = await ethers.getContractAt('StakeToken', xBtc)
    const preXTokenBalance = await xToken.balanceOf(user0.address)
    const requestId = await marketFacet.getLastUuid(MINT_ID_KEY)

    const oracles = [{ token: wbtcAddr, targetToken: ethers.ZeroAddress, minPrice: tokenPrice, maxPrice: tokenPrice }]
    await executeMint(fixture, {
      requestId: requestId,
      oracle: oracles,
    })

    // config
    const lpPoolConfig = await configFacet.getPoolConfig(xBtc)

    const poolInfo = await poolFacet.getPoolWithOracle(xBtc, oracles)
    const mintFee = precision.mulRate(requestTokenAmount, lpPoolConfig.mintFeeRate)

    const nextXTokenBalance = await xToken.balanceOf(user0.address)
    const nextVaultBalance1 = BigInt(await wbtc.balanceOf(lpVaultAddr))
    const nextMarketBalance = BigInt(await wbtc.balanceOf(xBtc))
    const nextEthVaultBalance1 = BigInt(await weth.balanceOf(portfolioVaultAddr))

    const realRequestTokenAmount = requestTokenAmount - mintFee

    // wallet
    expect(0).to.equals(nextVaultBalance1 - preVaultBalance)
    expect(requestTokenAmount).to.equals(nextMarketBalance - preMarketBalance)
    expect(executionFee).to.equals(nextEthVaultBalance - nextEthVaultBalance1)

    // xToken amount
    expect(realRequestTokenAmount).to.equals(nextXTokenBalance - preXTokenBalance)
    expect(realRequestTokenAmount).to.equals(await xToken.totalSupply())

    // pool
    expect(realRequestTokenAmount).to.equals(poolInfo.baseTokenBalance.amount)
    expect(0).to.equals(poolInfo.baseTokenBalance.liability)
    expect(0).to.equals(poolInfo.baseTokenBalance.holdAmount)
    expect(0).to.equals(poolInfo.baseTokenBalance.unsettledAmount)
    expect(0).to.equals(poolInfo.baseTokenBalance.lossAmount)
    expect(precision.mulPrice(realRequestTokenAmount, tokenPrice)).to.equals(poolInfo.poolValue)

    const availableLiquidity = precision.mulRate(realRequestTokenAmount, lpPoolConfig.poolLiquidityLimit)
    expect(availableLiquidity).to.equals(poolInfo.availableLiquidity)

    // Staking Account
    const stakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, xBtc)
    expect(realRequestTokenAmount).to.be.equals(stakingBalance.stakeAmount)

    await expect(
      stakeFacet
        .connect(user0)
        .executeMintStakeToken(requestId, [
          { token: wbtcAddr, targetToken: ethers.ZeroAddress, minPrice: tokenPrice, maxPrice: tokenPrice },
        ]),
    ).to.be.reverted
  })

  it('Case2: Mint xEth with WETH Success', async function () {
    const preBalance = BigInt(await weth.balanceOf(user0.address))
    const preVaultBalance = BigInt(await weth.balanceOf(lpVaultAddr))
    const preMarketBalance = BigInt(await weth.balanceOf(xEth))

    const tokenPrice = precision.price(1800)
    const requestTokenAmount = precision.token(1)
    const executionFee = precision.token(2, 15)

    await createMint(fixture, {
      receiver: user0.address,
      stakeToken: xEth,
      requestToken: weth,
      requestTokenAmount: requestTokenAmount,
      walletRequestTokenAmount: requestTokenAmount,
      minStakeAmount: precision.token(9, 17),
      isCollateral: false,
      isNativeToken: false,
      executionFee: executionFee,
    })

    const nextBalance = BigInt(await weth.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await weth.balanceOf(lpVaultAddr))

    // wallet
    expect(requestTokenAmount).to.equals(preBalance - nextBalance)
    expect(requestTokenAmount).to.equals(nextVaultBalance - preVaultBalance)

    const xToken = await ethers.getContractAt('StakeToken', xEth)
    const preXTokenBalance = await xToken.balanceOf(user0.address)
    const requestId = await marketFacet.getLastUuid(MINT_ID_KEY)
    const oracles = [{ token: wethAddr, targetToken: ethers.ZeroAddress, minPrice: tokenPrice, maxPrice: tokenPrice }]

    await executeMint(fixture, {
      requestId: requestId,
      oracle: oracles,
    })

    // config
    const lpPoolConfig = await configFacet.getPoolConfig(xEth)

    const poolInfo = await poolFacet.getPoolWithOracle(xEth, oracles)
    const mintFee = precision.mulRate(requestTokenAmount, lpPoolConfig.mintFeeRate)

    const realRequestTokenAmount = requestTokenAmount - mintFee

    const nextXTokenBalance = await xToken.balanceOf(user0.address)
    const nextVaultBalance1 = BigInt(await weth.balanceOf(lpVaultAddr))
    const nextMarketBalance = BigInt(await weth.balanceOf(xEth))

    // wallet
    expect(preVaultBalance).to.equals(nextVaultBalance1)
    expect(requestTokenAmount).to.equals(nextMarketBalance - preMarketBalance)

    // xToken amount
    expect(realRequestTokenAmount).to.equals(nextXTokenBalance - preXTokenBalance)
    expect(realRequestTokenAmount).to.equals(await xToken.totalSupply())

    // pool
    expect(realRequestTokenAmount).to.equals(poolInfo.baseTokenBalance.amount)
    expect(0).to.equals(poolInfo.baseTokenBalance.liability)
    expect(0).to.equals(poolInfo.baseTokenBalance.holdAmount)
    expect(0).to.equals(poolInfo.baseTokenBalance.unsettledAmount)
    expect(0).to.equals(poolInfo.baseTokenBalance.lossAmount)
    expect(precision.mulPrice(realRequestTokenAmount, tokenPrice)).to.equals(poolInfo.poolValue)

    const availableLiquidity = precision.mulRate(realRequestTokenAmount, lpPoolConfig.poolLiquidityLimit)
    expect(availableLiquidity).to.equals(poolInfo.availableLiquidity)

    // Staking Account
    const stakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, xEth)
    expect(realRequestTokenAmount).to.be.equals(stakingBalance.stakeAmount)
  })

  it('Case3: Multi Mint xEth by WETH/ETH, Oracle Price Fixed/Single User', async function () {
    const stakeToken = await ethers.getContractAt('StakeToken', xEth)
    const preWEthTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const preEthTokenBalance = BigInt(await ethers.provider.getBalance(user0.address))
    const preWEthVaultBalance = BigInt(await weth.balanceOf(lpVaultAddr))
    const preEthVaultBalance = BigInt(await ethers.provider.getBalance(wethAddr))
    const preWEthMarketBalance = BigInt(await weth.balanceOf(xEth))

    const preStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))

    const tokenPrice = precision.price(1800)
    const oracle = [{ token: wethAddr, minPrice: tokenPrice, maxPrice: tokenPrice }]

    const executionFee = precision.token(2, 15)

    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(100),
      oracle: oracle,
      executionFee: executionFee,
    })
    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(200),
      oracle: oracle,
      executionFee: executionFee,
    })
    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(300),
      oracle: oracle,
      isNativeToken: true,
      executionFee: executionFee,
    })

    const nextWEthTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const nextEthTokenBalance = BigInt(await ethers.provider.getBalance(user0.address))
    const nextWEthVaultBalance = BigInt(await weth.balanceOf(lpVaultAddr))
    const nextWEthMarketBalance = BigInt(await weth.balanceOf(xEth))
    const nextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))

    // config
    const lpPoolConfig = await configFacet.getPoolConfig(xEth)

    const poolInfo = await poolFacet.getPoolWithOracle(xEth, oracles.format(oracle))
    const totalRequestTokenAmount = precision.token(100 + 200 + 300)
    const mintFee = precision.mulRate(totalRequestTokenAmount, lpPoolConfig.mintFeeRate)
    const realRequestTokenAmount = totalRequestTokenAmount - mintFee

    // vault & user token amount
    expect(0).to.equals(nextWEthVaultBalance - preWEthVaultBalance)
    expect(totalRequestTokenAmount).to.equals(nextWEthMarketBalance - preWEthMarketBalance)
    expect(-precision.token(100 + 200)).to.equals(nextWEthTokenBalance - preWEthTokenBalance)

    expect(preEthTokenBalance - nextEthTokenBalance).to.be.within(
      precision.token(300),
      precision.token(300) + executionFee * BigInt(6),
    )

    // xToken amount
    expect(realRequestTokenAmount).to.equals(nextStakeTokenBalance - preStakeTokenBalance)

    // pool
    expect(realRequestTokenAmount).to.equals(poolInfo.baseTokenBalance.amount)
    expect(0).to.equals(poolInfo.baseTokenBalance.liability)
    expect(0).to.equals(poolInfo.baseTokenBalance.holdAmount)
    expect(0).to.equals(poolInfo.baseTokenBalance.unsettledAmount)
    expect(0).to.equals(poolInfo.baseTokenBalance.lossAmount)

    expect(precision.mulPrice(realRequestTokenAmount, tokenPrice)).to.equals(poolInfo.poolValue)
    const availableLiquidity = precision.mulRate(realRequestTokenAmount, lpPoolConfig.poolLiquidityLimit)
    expect(availableLiquidity).to.equals(poolInfo.availableLiquidity)

    // Staking Account
    const stakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, xEth)
    expect(realRequestTokenAmount).to.be.equals(stakingBalance.stakeAmount)
  })

  it('Case4: Multi Mint xEth by WETH, Oracle Price Fixed/Multi User', async function () {
    const stakeToken = await ethers.getContractAt('StakeToken', xEth)
    const preVaultBalance = BigInt(await weth.balanceOf(lpVaultAddr))
    const preMarketBalance = BigInt(await weth.balanceOf(xEth))
    // const preTotalFee = await feeFacet.getTokenFee(xEth, wethAddr)

    const user0PreTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const user0PreStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))

    const user1PreTokenBalance = BigInt(await weth.balanceOf(user1.address))
    const user1PreStakeTokenBalance = BigInt(await stakeToken.balanceOf(user1.address))

    const user2PreTokenBalance = BigInt(await weth.balanceOf(user2.address))
    const user2PreStakeTokenBalance = BigInt(await stakeToken.balanceOf(user2.address))

    const tokenPrice = precision.price(1800)
    const oracle = [{ token: wethAddr, minPrice: tokenPrice, maxPrice: tokenPrice }]
    const executionFee = precision.token(2, 15)

    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(100),
      oracle: oracle,
      account: user0,
      executionFee: executionFee,
    })
    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(90),
      oracle: oracle,
      account: user1,
      executionFee: executionFee,
    })
    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(77),
      oracle: oracle,
      account: user2,
      executionFee: executionFee,
    })
    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(200),
      oracle: oracle,
      account: user0,
      executionFee: executionFee,
    })
    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(300),
      oracle: oracle,
      account: user0,
      executionFee: executionFee,
    })
    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(88),
      oracle: oracle,
      account: user1,
      executionFee: executionFee,
    })
    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(99),
      oracle: oracle,
      account: user2,
      executionFee: executionFee,
    })

    const totalRequestToken = precision.token(100 + 90 + 77 + 200 + 300 + 88 + 99)

    const nextVaultBalance = BigInt(await weth.balanceOf(lpVaultAddr))
    const nextMarketBalance = BigInt(await weth.balanceOf(xEth))

    const user0NextTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const user0NextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))

    const user1NextTokenBalance = BigInt(await weth.balanceOf(user1.address))
    const user1NextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user1.address))

    const user2NextTokenBalance = BigInt(await weth.balanceOf(user2.address))
    const user2NextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user2.address))

    // config
    const lpPoolConfig = await configFacet.getPoolConfig(xEth)

    const poolInfo = await poolFacet.getPoolWithOracle(xEth, oracles.format(oracle))
    const mintFee = precision.mulRate(totalRequestToken, lpPoolConfig.mintFeeRate)

    const realRequestTokenAmount = totalRequestToken - mintFee

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(totalRequestToken).to.equals(nextMarketBalance - preMarketBalance)
    expect(totalRequestToken).to.equals(
      user0PreTokenBalance +
        user1PreTokenBalance +
        user2PreTokenBalance -
        user0NextTokenBalance -
        user1NextTokenBalance -
        user2NextTokenBalance,
    )

    // xToken amount
    expect(realRequestTokenAmount).to.equals(
      user0NextStakeTokenBalance +
        user1NextStakeTokenBalance +
        user2NextStakeTokenBalance -
        user0PreStakeTokenBalance -
        user1PreStakeTokenBalance -
        user2PreStakeTokenBalance,
    )

    // pool
    expect(realRequestTokenAmount).to.equals(poolInfo.baseTokenBalance.amount)
    expect(0).to.equals(poolInfo.baseTokenBalance.liability)
    expect(0).to.equals(poolInfo.baseTokenBalance.holdAmount)
    expect(0).to.equals(poolInfo.baseTokenBalance.unsettledAmount)
    expect(0).to.equals(poolInfo.baseTokenBalance.lossAmount)

    expect(precision.mulPrice(realRequestTokenAmount, tokenPrice)).to.equals(poolInfo.poolValue)
    const availableLiquidity = precision.mulRate(realRequestTokenAmount, lpPoolConfig.poolLiquidityLimit)
    expect(availableLiquidity).to.equals(poolInfo.availableLiquidity)

    // Staking Account
    const user0StakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, xEth)
    const user1StakingBalance = await stakingAccountFacet.getAccountPoolBalance(user1.address, xEth)
    const user2StakingBalance = await stakingAccountFacet.getAccountPoolBalance(user2.address, xEth)
    expect(realRequestTokenAmount).to.be.equals(
      user0StakingBalance.stakeAmount + user1StakingBalance.stakeAmount + user2StakingBalance.stakeAmount,
    )
  })

  it('Case5: Multi Mint xEth by WETH, Oracle Price Float/Multi User', async function () {
    const stakeToken = await ethers.getContractAt('StakeToken', xEth)
    const preVaultBalance = BigInt(await weth.balanceOf(lpVaultAddr))
    const preMarketBalance = BigInt(await weth.balanceOf(lpVaultAddr))

    const user0PreTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const user0PreStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))

    const user1PreTokenBalance = BigInt(await weth.balanceOf(user1.address))
    const user1PreStakeTokenBalance = BigInt(await stakeToken.balanceOf(user1.address))

    const user2PreTokenBalance = BigInt(await weth.balanceOf(user2.address))
    const user2PreStakeTokenBalance = BigInt(await stakeToken.balanceOf(user2.address))

    const tokenPrice1 = precision.price(1800)
    const oracle1 = [{ token: wethAddr, minPrice: tokenPrice1, maxPrice: tokenPrice1 }]

    const user0RequestTokenAmount1 = precision.token(100)
    const executionFee = precision.token(2, 15)

    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: user0RequestTokenAmount1,
      oracle: oracle1,
      account: user0,
      executionFee: executionFee,
    })

    const user1RequestTokenAmount1 = precision.token(90)

    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: user1RequestTokenAmount1,
      oracle: oracle1,
      account: user1,
      executionFee: executionFee,
    })

    const nextVaultBalance1 = BigInt(await weth.balanceOf(lpVaultAddr))
    const nextMarketBalance1 = BigInt(await weth.balanceOf(xEth))

    const user0NextTokenBalance1 = BigInt(await weth.balanceOf(user0.address))
    const user0NextStakeTokenBalance1 = BigInt(await stakeToken.balanceOf(user0.address))

    const user1NextTokenBalance1 = BigInt(await weth.balanceOf(user1.address))
    const user1NextStakeTokenBalance1 = BigInt(await stakeToken.balanceOf(user1.address))

    const user2NextTokenBalance1 = BigInt(await weth.balanceOf(user2.address))
    const user2NextStakeTokenBalance1 = BigInt(await stakeToken.balanceOf(user2.address))

    const poolInfo1 = await poolFacet.getPoolWithOracle(xEth, oracles.format(oracle1))

    // config
    const lpPoolConfig = await configFacet.getPoolConfig(xEth)

    // vault & user token amount
    expect(user0RequestTokenAmount1 + user1RequestTokenAmount1).to.equals(nextMarketBalance1 - preMarketBalance)
    expect(0).to.equals(nextVaultBalance1 - preVaultBalance)
    expect(user0RequestTokenAmount1).to.equals(user0PreTokenBalance - user0NextTokenBalance1)
    expect(user1RequestTokenAmount1).to.equals(user1PreTokenBalance - user1NextTokenBalance1)
    expect(0).to.equals(user2PreTokenBalance - user2NextTokenBalance1)

    // Fee
    const user0Fee1 = precision.mulRate(user0RequestTokenAmount1, lpPoolConfig.mintFeeRate)
    const user1Fee1 = precision.mulRate(user1RequestTokenAmount1, lpPoolConfig.mintFeeRate)

    // xToken amount
    const user0RealRequestTokenAmount1 = user0RequestTokenAmount1 - user0Fee1
    const user1RealRequestTokenAmount1 = user1RequestTokenAmount1 - user1Fee1
    expect(user0RealRequestTokenAmount1).to.equals(user0NextStakeTokenBalance1 - user0PreStakeTokenBalance)
    expect(user1RealRequestTokenAmount1).to.equals(user1NextStakeTokenBalance1 - user1PreStakeTokenBalance)
    expect(0).to.equals(user2NextStakeTokenBalance1 - user2PreStakeTokenBalance)

    // pool
    expect(user0RealRequestTokenAmount1 + user1RealRequestTokenAmount1).to.equals(poolInfo1.baseTokenBalance.amount)
    expect(precision.mulPrice(user0RealRequestTokenAmount1 + user1RealRequestTokenAmount1, tokenPrice1)).to.equals(
      poolInfo1.poolValue,
    )
    const availableLiquidity = precision.mulRate(
      user0RealRequestTokenAmount1 + user1RealRequestTokenAmount1,
      lpPoolConfig.poolLiquidityLimit,
    )
    expect(availableLiquidity).to.equals(poolInfo1.availableLiquidity)

    // Staking Account
    const user0StakingBalance1 = await stakingAccountFacet.getAccountPoolBalance(user0.address, xEth)
    const user1StakingBalance1 = await stakingAccountFacet.getAccountPoolBalance(user1.address, xEth)
    const user2StakingBalance1 = await stakingAccountFacet.getAccountPoolBalance(user2.address, xEth)
    expect(user0RealRequestTokenAmount1).to.be.equals(user0StakingBalance1.stakeAmount)
    expect(user1RealRequestTokenAmount1).to.be.equals(user1StakingBalance1.stakeAmount)
    expect(0).to.be.equals(user2StakingBalance1.stakeAmount)

    const tokenPrice2 = precision.price(1820)
    const oracle2 = [{ token: wethAddr, minPrice: tokenPrice2, maxPrice: tokenPrice2 }]

    const user2requestTokenAmount2 = precision.token(77)

    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: user2requestTokenAmount2,
      oracle: oracle2,
      account: user2,
      receiver: user2.address,
      executionFee: executionFee,
    })

    const user0requestTokenAmount2 = precision.token(200)

    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: precision.token(200),
      oracle: oracle2,
      account: user0,
      receiver: user0.address,
      executionFee: executionFee,
    })

    const nextVaultBalance2 = BigInt(await weth.balanceOf(lpVaultAddr))
    const nextMarketBalance2 = BigInt(await weth.balanceOf(xEth))

    const user0NextTokenBalance2 = BigInt(await weth.balanceOf(user0.address))
    const user0NextStakeTokenBalance2 = BigInt(await stakeToken.balanceOf(user0.address))

    const user1NextTokenBalance2 = BigInt(await weth.balanceOf(user1.address))
    const user1NextStakeTokenBalance2 = BigInt(await stakeToken.balanceOf(user1.address))

    const user2NextTokenBalance2 = BigInt(await weth.balanceOf(user2.address))
    const user2NextStakeTokenBalance2 = BigInt(await stakeToken.balanceOf(user2.address))

    const poolInfo2 = await poolFacet.getPoolWithOracle(xEth, oracles.format(oracle2))

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance2 - nextVaultBalance1)
    expect(user0requestTokenAmount2 + user2requestTokenAmount2).to.equals(nextMarketBalance2 - nextMarketBalance1)
    expect(user0requestTokenAmount2).to.equals(user0NextTokenBalance1 - user0NextTokenBalance2)
    expect(user2requestTokenAmount2).to.equals(user2NextTokenBalance1 - user2NextTokenBalance2)
    expect(0).to.equals(user1NextTokenBalance1 - user1NextTokenBalance2)

    // Fee
    const user0Fee2 = precision.mulRate(user0requestTokenAmount2, lpPoolConfig.mintFeeRate)
    const user2Fee2 = precision.mulRate(user2requestTokenAmount2, lpPoolConfig.mintFeeRate)

    // xToken amount
    const user0RealRequestTokenAmount2 = user0requestTokenAmount2 - user0Fee2
    const user2RealRequestTokenAmount2 = user2requestTokenAmount2 - user2Fee2
    expect(user0RealRequestTokenAmount2).to.equals(user0NextStakeTokenBalance2 - user0NextStakeTokenBalance1)
    expect(user2RealRequestTokenAmount2).to.equals(user2NextStakeTokenBalance2 - user2NextStakeTokenBalance1)
    expect(0).to.equals(user1NextStakeTokenBalance2 - user1NextStakeTokenBalance1)

    // pool
    expect(user0RealRequestTokenAmount2 + user2RealRequestTokenAmount2).to.equals(
      poolInfo2.baseTokenBalance.amount - poolInfo1.baseTokenBalance.amount,
    )
    expect(
      precision.mulPrice(
        user0RealRequestTokenAmount2 + user2RealRequestTokenAmount2 + poolInfo1.baseTokenBalance.amount,
        tokenPrice2,
      ),
    ).to.equals(poolInfo2.poolValue)
    const availableLiquidity2 = precision.mulRate(
      user0RealRequestTokenAmount2 + user2RealRequestTokenAmount2 + poolInfo1.baseTokenBalance.amount,
      lpPoolConfig.poolLiquidityLimit,
    )
    expect(availableLiquidity2).to.equals(poolInfo2.availableLiquidity)

    // Staking Account
    const user0StakingBalance2 = await stakingAccountFacet.getAccountPoolBalance(user0.address, xEth)
    const user1StakingBalance2 = await stakingAccountFacet.getAccountPoolBalance(user1.address, xEth)
    const user2StakingBalance2 = await stakingAccountFacet.getAccountPoolBalance(user2.address, xEth)
    expect(user0RealRequestTokenAmount2).to.be.equals(
      user0StakingBalance2.stakeAmount - user0StakingBalance1.stakeAmount,
    )
    expect(0).to.be.equals(user1StakingBalance2.stakeAmount - user1StakingBalance1.stakeAmount)
    expect(user2RealRequestTokenAmount2).to.be.equals(
      user2StakingBalance2.stakeAmount - user2StakingBalance1.stakeAmount,
    )

    const tokenPrice3 = precision.price(1780)
    const oracle3 = [{ token: wethAddr, minPrice: tokenPrice3, maxPrice: tokenPrice3 }]

    const user0requestTokenAmount3 = precision.token(300)

    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: user0requestTokenAmount3,
      oracle: oracle3,
      account: user0,
      receiver: user0.address,
      executionFee: executionFee,
    })

    const user1requestTokenAmount3 = precision.token(88)

    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: user1requestTokenAmount3,
      oracle: oracle3,
      account: user1,
      receiver: user1.address,
      executionFee: executionFee,
    })

    const user2requestTokenAmount3 = precision.token(99)

    await handleMint(fixture, {
      requestToken: weth,
      requestTokenAmount: user2requestTokenAmount3,
      oracle: oracle3,
      account: user2,
      receiver: user2.address,
      executionFee: executionFee,
    })

    const nextVaultBalance3 = BigInt(await weth.balanceOf(lpVaultAddr))
    const nextMarketBalance3 = BigInt(await weth.balanceOf(xEth))

    const user0NextTokenBalance3 = BigInt(await weth.balanceOf(user0.address))
    const user0NextStakeTokenBalance3 = BigInt(await stakeToken.balanceOf(user0.address))

    const user1NextTokenBalance3 = BigInt(await weth.balanceOf(user1.address))
    const user1NextStakeTokenBalance3 = BigInt(await stakeToken.balanceOf(user1.address))

    const user2NextTokenBalance3 = BigInt(await weth.balanceOf(user2.address))
    const user2NextStakeTokenBalance3 = BigInt(await stakeToken.balanceOf(user2.address))

    const poolInfo3 = await poolFacet.getPoolWithOracle(xEth, oracles.format(oracle3))

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance3 - nextVaultBalance2)
    expect(user0requestTokenAmount3 + user1requestTokenAmount3 + user2requestTokenAmount3).to.equals(
      nextMarketBalance3 - nextMarketBalance2,
    )
    expect(user0requestTokenAmount3).to.equals(user0NextTokenBalance2 - user0NextTokenBalance3)
    expect(user1requestTokenAmount3).to.equals(user1NextTokenBalance2 - user1NextTokenBalance3)
    expect(user2requestTokenAmount3).to.equals(user2NextTokenBalance2 - user2NextTokenBalance3)

    // Fee
    const user0Fee3 = precision.mulRate(user0requestTokenAmount3, lpPoolConfig.mintFeeRate)
    const user1Fee3 = precision.mulRate(user1requestTokenAmount3, lpPoolConfig.mintFeeRate)
    const user2Fee3 = precision.mulRate(user2requestTokenAmount3, lpPoolConfig.mintFeeRate)

    // xToken amount
    const user0RealRequestTokenAmount3 = user0requestTokenAmount3 - user0Fee3
    const user1RealRequestTokenAmount3 = user1requestTokenAmount3 - user1Fee3
    const user2RealRequestTokenAmount3 = user2requestTokenAmount3 - user2Fee3
    expect(user0RealRequestTokenAmount3).to.equals(user0NextStakeTokenBalance3 - user0NextStakeTokenBalance2)
    expect(user1RealRequestTokenAmount3).to.equals(user1NextStakeTokenBalance3 - user1NextStakeTokenBalance2)
    expect(user2RealRequestTokenAmount3).to.equals(user2NextStakeTokenBalance3 - user2NextStakeTokenBalance2)

    // pool
    expect(user0RealRequestTokenAmount3 + user1RealRequestTokenAmount3 + user2RealRequestTokenAmount3).to.equals(
      poolInfo3.baseTokenBalance.amount - poolInfo2.baseTokenBalance.amount,
    )
    expect(
      precision.mulPrice(
        user0RealRequestTokenAmount3 +
          user1RealRequestTokenAmount3 +
          user2RealRequestTokenAmount3 +
          poolInfo2.baseTokenBalance.amount,
        tokenPrice3,
      ),
    ).to.equals(poolInfo3.poolValue)
    const availableLiquidity3 = precision.mulRate(
      user0RealRequestTokenAmount3 +
        user1RealRequestTokenAmount3 +
        user2RealRequestTokenAmount3 +
        poolInfo2.baseTokenBalance.amount,
      lpPoolConfig.poolLiquidityLimit,
    )
    expect(availableLiquidity3).to.equals(poolInfo3.availableLiquidity)

    // Staking Account
    const user0StakingBalance3 = await stakingAccountFacet.getAccountPoolBalance(user0.address, xEth)
    const user1StakingBalance3 = await stakingAccountFacet.getAccountPoolBalance(user1.address, xEth)
    const user2StakingBalance3 = await stakingAccountFacet.getAccountPoolBalance(user2.address, xEth)
    expect(user0RealRequestTokenAmount3).to.be.equals(
      user0StakingBalance3.stakeAmount - user0StakingBalance2.stakeAmount,
    )
    expect(user1RealRequestTokenAmount3).to.be.equals(
      user1StakingBalance3.stakeAmount - user1StakingBalance2.stakeAmount,
    )
    expect(user2RealRequestTokenAmount3).to.be.equals(
      user2StakingBalance3.stakeAmount - user2StakingBalance2.stakeAmount,
    )
  })
})
