import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { precision } from '@utils/precision'
import { handleMint } from '@utils/mint'
import { AccountFacet, ConfigFacet, FeeFacet, MockToken, PoolFacet, StakingAccountFacet } from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'
import { createRedeemWrapper, handleRedeem } from '@utils/redeem'
import { account } from '@utils/account'

describe('Redeem xToken Test', function () {
  let fixture: Fixture
  let poolFacet: PoolFacet, accountFacet: AccountFacet, stakingAccountFacet: StakingAccountFacet, feeFacet: FeeFacet
  let configFacet: ConfigFacet
  let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner, user3: HardhatEthersSigner
  let portfolioVaultAddr: string,
    wbtcAddr: string,
    wethAddr: string,
    usdcAddr: string
  let xBtc: string, xEth: string, xUsd: string
  let wbtc: MockToken, weth: MockToken, usdc: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ poolFacet, accountFacet, stakingAccountFacet, feeFacet, configFacet } = fixture.contracts)
    ;({ user0, user1, user2, user3 } = fixture.accounts)
    ;({ xBtc, xEth, xUsd } = fixture.pools)
    ;({ portfolioVaultAddr } = fixture.addresses)
    ;({ wbtc, weth, usdc } = fixture.tokens)
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

    await handleMint(fixture, {
      stakeToken: xBtc,
      requestToken: wbtc,
      requestTokenAmount: precision.token(100),
      oracle: btcOracle,
      account: user1,
      receiver: user1.address,
    })

    await handleMint(fixture, {
      stakeToken: xBtc,
      requestToken: wbtc,
      requestTokenAmount: precision.token(100),
      oracle: btcOracle,
      account: user2,
      receiver: user2.address,
    })

    const ethTokenPrice = precision.price(1600)
    const ethOracle = [{ token: wethAddr, minPrice: ethTokenPrice, maxPrice: ethTokenPrice }]
    await handleMint(fixture, {
      requestTokenAmount: precision.token(1000),
      oracle: ethOracle,
    })

    await handleMint(fixture, {
      requestTokenAmount: precision.token(1000),
      oracle: ethOracle,
      account: user1,
    })

    await handleMint(fixture, {
      requestTokenAmount: precision.token(1000),
      oracle: ethOracle,
      account: user2,
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

    await handleMint(fixture, {
      requestTokenAmount: precision.token(100000, 6),
      stakeToken: xUsd,
      requestToken: usdc,
      oracle: usdOracle,
      account: user1,
    })

    await handleMint(fixture, {
      requestTokenAmount: precision.token(100000, 6),
      stakeToken: xUsd,
      requestToken: usdc,
      oracle: usdOracle,
      account: user2,
    })
    
  })

  it('Case0: Redeem xToken errors', async function () {
    // redeem amount zero
    await expect(createRedeemWrapper(fixture, { unStakeAmount: 0 })).to.be.reverted

    // receiver error
    await expect(createRedeemWrapper(fixture, { unStakeAmount: precision.token(10), receiver: ethers.ZeroAddress })).to
      .be.reverted

    // stake pool zero
    await expect(createRedeemWrapper(fixture, { stakeToken: ethers.ZeroAddress, unStakeAmount: precision.token(10) }))
      .to.be.reverted

    // stake pool error
    await expect(createRedeemWrapper(fixture, { stakeToken: wbtcAddr, unStakeAmount: precision.token(10) })).to.be
      .reverted

    // redeem token error
    await expect(
      createRedeemWrapper(fixture, { stakeToken: xEth, redeemToken: wbtc, unStakeAmount: precision.token(10) }),
    ).to.be.reverted

    // redeem with no balance
    await expect(
      createRedeemWrapper(fixture, {
        stakeToken: xEth,
        redeemToken: weth,
        account: user3,
        unStakeAmount: precision.token(10),
      }),
    ).to.be.reverted
  })

  it('Case1: Redeem WBTC with xBtc Success, Once', async function () {
    const stakeToken = await ethers.getContractAt('StakeToken', xBtc)

    const preStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))
    const preTokenBalance = BigInt(await wbtc.balanceOf(user0.address))
    const prePortfolioVaultBalance = BigInt(await wbtc.balanceOf(portfolioVaultAddr))
    const preMarketBalance = BigInt(await wbtc.balanceOf(xBtc))
    const preStakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, xBtc)
    const prePoolInfo = await poolFacet.getPool(xBtc)

    // config
    const xBTCPoolConfig = await configFacet.getPoolConfig(xBtc)
    const xBTCRedeemFeeRate = xBTCPoolConfig.redeemFeeRate

    const unStakeAmount = precision.token(1, 17) //0.1xBtc
    const tokenPrice = precision.price(25000)

    await handleRedeem(fixture, {
      stakeToken: xBtc,
      redeemToken: wbtc,
      unStakeAmount: unStakeAmount,
      oracle: [{ token: wbtcAddr, minPrice: tokenPrice, maxPrice: tokenPrice }],
    })

    const redeemTokenAmountOrigin = precision.divPrice(
      unStakeAmount * (precision.mulPrice(prePoolInfo.baseTokenBalance.amount, tokenPrice) / prePoolInfo.totalSupply),
      tokenPrice,
    )
    const redeemFee = precision.mulRate(redeemTokenAmountOrigin, xBTCRedeemFeeRate)

    const redeemTokenAmount = redeemTokenAmountOrigin

    // wallet/xToken amount
    const nextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))
    const nextTokenBalance = BigInt(await wbtc.balanceOf(user0.address))
    const nextMarketBalance = BigInt(await wbtc.balanceOf(xBtc))
    const nextPortfolioVaultBalance = BigInt(await wbtc.balanceOf(portfolioVaultAddr))

    expect(-unStakeAmount).to.equals(nextStakeTokenBalance - preStakeTokenBalance)
    expect(redeemTokenAmount).to.equals(nextTokenBalance - preTokenBalance)
    expect(0).to.equals(nextPortfolioVaultBalance - prePortfolioVaultBalance)
    expect(-redeemTokenAmount).to.equals(nextMarketBalance - preMarketBalance)

    const nextPoolInfo = await poolFacet.getPool(xBtc)

    // pool
    expect(redeemTokenAmountOrigin).to.equals(
      prePoolInfo.baseTokenBalance.amount - nextPoolInfo.baseTokenBalance.amount,
    )

    // Staking Account
    const nextStakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, xBtc)
    expect(-unStakeAmount).to.be.equals(nextStakingBalance.stakeAmount - preStakingBalance.stakeAmount)
  })

  it('Case2: Redeem WETH with xEth Success, Multi Redeem/Single User/Price Float', async function () {
    const stakeTokenAddr = xEth
    const stakeToken = await ethers.getContractAt('StakeToken', xEth)

    const preStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))
    const preTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const preVaultBalance = BigInt(await weth.balanceOf(portfolioVaultAddr))
    const preMarketBalance = BigInt(await weth.balanceOf(xEth))
    const preStakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, stakeTokenAddr)
    const prePoolInfo = await poolFacet.getPool(stakeTokenAddr)

    // config
    const stakeTokenPoolConfig = await configFacet.getPoolConfig(stakeTokenAddr)
    const redeemFeeRate = stakeTokenPoolConfig.redeemFeeRate

    const unStakeAmount = precision.token(5) //5 xEth
    const tokenPrice = precision.price(1700)

    await handleRedeem(fixture, {
      unStakeAmount: unStakeAmount,
      oracle: [{ token: wethAddr, minPrice: tokenPrice, maxPrice: tokenPrice }],
    })

    const redeemTokenAmountOrigin = precision.divPrice(
      unStakeAmount * (precision.mulPrice(prePoolInfo.baseTokenBalance.amount, tokenPrice) / prePoolInfo.totalSupply),
      tokenPrice,
    )
    const redeemFee = precision.mulRate(redeemTokenAmountOrigin, redeemFeeRate)
    const redeemTokenAmount = redeemTokenAmountOrigin

    // wallet/xToken amount
    const nextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))
    const nextTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await weth.balanceOf(portfolioVaultAddr))
    const nextMarketBalance = BigInt(await weth.balanceOf(xEth))

    expect(-unStakeAmount).to.equals(nextStakeTokenBalance - preStakeTokenBalance)
    expect(redeemTokenAmount).to.equals(nextTokenBalance - preTokenBalance)
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(-redeemTokenAmount).to.equals(nextMarketBalance - preMarketBalance)

    const nextPoolInfo = await poolFacet.getPool(stakeTokenAddr)

    // pool
    expect(redeemTokenAmountOrigin).to.equals(
      prePoolInfo.baseTokenBalance.amount - nextPoolInfo.baseTokenBalance.amount,
    )

    // Staking Account
    const nextStakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, stakeTokenAddr)
    expect(-unStakeAmount).to.be.equals(nextStakingBalance.stakeAmount - preStakingBalance.stakeAmount)

    // Account
    // const accountInfo = await accountFacet.getAccountInfo(user0.address)
    // expect(redeemTokenAmount).to.equals(account.getAccountTokenAmount(accountInfo, wethAddr))

    const unStakeAmount1 = precision.token(30)
    const tokenPrice1 = precision.price(1720)

    await handleRedeem(fixture, {
      unStakeAmount: unStakeAmount1,
      oracle: [{ token: wethAddr, minPrice: tokenPrice1, maxPrice: tokenPrice1 }],
    })

    const redeemTokenAmountOrigin1 = precision.divPrice(
      unStakeAmount1 *
        (precision.mulPrice(nextPoolInfo.baseTokenBalance.amount, tokenPrice1) / nextPoolInfo.totalSupply),
      tokenPrice1,
    )
    const redeemFee1 = precision.mulRate(redeemTokenAmountOrigin1, redeemFeeRate)
    const redeemTokenAmount1 = redeemTokenAmountOrigin1

    // wallet/xToken amount
    const nextStakeTokenBalance1 = BigInt(await stakeToken.balanceOf(user0.address))
    const nextTokenBalance1 = BigInt(await weth.balanceOf(user0.address))
    const nextVaultBalance1 = BigInt(await weth.balanceOf(portfolioVaultAddr))
    const nextMarketBalance1 = BigInt(await weth.balanceOf(xEth))

    expect(-unStakeAmount1).to.equals(nextStakeTokenBalance1 - nextStakeTokenBalance)
    expect(redeemTokenAmount1).to.equals(nextTokenBalance1 - nextTokenBalance)
    expect(0).to.equals(nextVaultBalance1 - nextVaultBalance)
    expect(-redeemTokenAmount1).to.equals(nextMarketBalance1 - nextMarketBalance)

    const nextPoolInfo1 = await poolFacet.getPool(stakeTokenAddr)

    // pool
    expect(redeemTokenAmountOrigin1).to.equals(
      nextPoolInfo.baseTokenBalance.amount - nextPoolInfo1.baseTokenBalance.amount,
    )

    // Staking Account
    const nextStakingBalance1 = await stakingAccountFacet.getAccountPoolBalance(user0.address, stakeTokenAddr)
    expect(-unStakeAmount1).to.be.equals(nextStakingBalance1.stakeAmount - nextStakingBalance.stakeAmount)
  })

  it('Case3: Redeem WETH with xEth Success, Multi Redeem/Multi User/Price Float', async function () {
    const stakeTokenAddr = xEth
    const stakeToken = await ethers.getContractAt('StakeToken', xEth)

    const preStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))
    const preTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const preVaultBalance = BigInt(await weth.balanceOf(portfolioVaultAddr))
    const preMarketBalance = BigInt(await weth.balanceOf(xEth))
    const preStakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, stakeTokenAddr)
    const prePoolInfo = await poolFacet.getPool(stakeTokenAddr)

    const stakeTokenPoolConfig = await configFacet.getPoolConfig(stakeTokenAddr)
    const redeemFeeRate = stakeTokenPoolConfig.redeemFeeRate

    const unStakeAmount = precision.token(5) //5 xEth
    const tokenPrice = precision.price(1700)

    await handleRedeem(fixture, {
      unStakeAmount: unStakeAmount,
      oracle: [{ token: wethAddr, minPrice: tokenPrice, maxPrice: tokenPrice }],
    })

    const redeemTokenAmountOrigin = precision.divPrice(
      unStakeAmount * (precision.mulPrice(prePoolInfo.baseTokenBalance.amount, tokenPrice) / prePoolInfo.totalSupply),
      tokenPrice,
    )
    const redeemFee = precision.mulRate(redeemTokenAmountOrigin, redeemFeeRate)
    const redeemTokenAmount = redeemTokenAmountOrigin

    // wallet/xToken amount
    const nextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))
    const nextTokenBalance = BigInt(await weth.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await weth.balanceOf(portfolioVaultAddr))
    const nextMarketBalance = BigInt(await weth.balanceOf(xEth))

    expect(-unStakeAmount).to.equals(nextStakeTokenBalance - preStakeTokenBalance)
    expect(redeemTokenAmount).to.equals(nextTokenBalance - preTokenBalance)
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(-redeemTokenAmount).to.equals(nextMarketBalance - preMarketBalance)

    const nextPoolInfo = await poolFacet.getPool(stakeTokenAddr)

    // pool
    expect(redeemTokenAmountOrigin).to.equals(
      prePoolInfo.baseTokenBalance.amount - nextPoolInfo.baseTokenBalance.amount,
    )

    // Staking Account
    const nextStakingBalance = await stakingAccountFacet.getAccountPoolBalance(user0.address, stakeTokenAddr)
    expect(-unStakeAmount).to.be.equals(nextStakingBalance.stakeAmount - preStakingBalance.stakeAmount)

    const preUser1StakeTokenBalance = BigInt(await stakeToken.balanceOf(user1.address))
    const preUser1TokenBalance = BigInt(await weth.balanceOf(user1.address))
    const preUser1StakingBalance = await stakingAccountFacet.getAccountPoolBalance(user1.address, stakeTokenAddr)
    const unStakeAmount1 = precision.token(30)
    const tokenPrice1 = precision.price(1801)

    await handleRedeem(fixture, {
      unStakeAmount: unStakeAmount1,
      account: user1,
      receiver: user1.address,
      oracle: [{ token: wethAddr, minPrice: tokenPrice1, maxPrice: tokenPrice1 }],
    })

    const redeemTokenAmountOrigin1 = precision.divPrice(
      unStakeAmount1 *
        (precision.mulPrice(nextPoolInfo.baseTokenBalance.amount, tokenPrice1) / nextPoolInfo.totalSupply),
      tokenPrice1,
    )
    const redeemFee1 = precision.mulRate(redeemTokenAmountOrigin1, redeemFeeRate)
    const redeemTokenAmount1 = redeemTokenAmountOrigin1

    // wallet/xToken amount
    const nextUser1StakeTokenBalance1 = BigInt(await stakeToken.balanceOf(user1.address))
    const nextUser1TokenBalance1 = BigInt(await weth.balanceOf(user1.address))
    const nextVaultBalance1 = BigInt(await weth.balanceOf(portfolioVaultAddr))
    const nextMarketBalance1 = BigInt(await weth.balanceOf(xEth))

    expect(-unStakeAmount1).to.equals(nextUser1StakeTokenBalance1 - preUser1StakeTokenBalance)
    expect(redeemTokenAmount1).to.equals(nextUser1TokenBalance1 - preUser1TokenBalance)
    expect(0).to.equals(nextVaultBalance1 - nextVaultBalance)
    expect(-redeemTokenAmount1).to.equals(nextMarketBalance1 - nextMarketBalance)

    const nextPoolInfo1 = await poolFacet.getPool(stakeTokenAddr)

    // pool
    expect(redeemTokenAmountOrigin1).to.equals(
      nextPoolInfo.baseTokenBalance.amount - nextPoolInfo1.baseTokenBalance.amount,
    )

    // Staking Account
    const nextUser1StakingBalance1 = await stakingAccountFacet.getAccountPoolBalance(user1.address, stakeTokenAddr)
    expect(-unStakeAmount1).to.be.equals(nextUser1StakingBalance1.stakeAmount - preUser1StakingBalance.stakeAmount)
  })
})
