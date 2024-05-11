import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { precision } from '@utils/precision'
import { createMintWrapper, handleMint } from '@utils/mint'
import { ConfigFacet, FeeFacet, LpVault, MarketFacet, MockToken, PoolFacet, StakingAccountFacet } from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'

describe('Mint xUsd Test', function () {
  let fixture: Fixture
  let poolFacet: PoolFacet, stakingAccountFacet: StakingAccountFacet, feeFacet: FeeFacet
  let configFacet: ConfigFacet
  let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner
  let lpVaultAddr: string, usdcAddr: string
  let xUsd: string
  let wbtc: MockToken, usdc: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ poolFacet, stakingAccountFacet, feeFacet, configFacet } = fixture.contracts)
    ;({ user0, user1, user2 } = fixture.accounts)
    ;({ xUsd } = fixture.pools)
    ;({ wbtc, usdc } = fixture.tokens)
    ;({ lpVaultAddr } = fixture.addresses)
    usdcAddr = await usdc.getAddress()
  })

  it('Case0: Mint xUsd Errors', async function () {
    await expect(createMintWrapper(fixture, { stakeToken: xUsd, requestTokenAmount: 0 })).to.be.reverted

    await expect(
      createMintWrapper(fixture, { stakeToken: xUsd, requestToken: wbtc, requestTokenAmount: precision.token(100, 6) }),
    ).to.be.reverted

    const mintUsdtAmount = precision.token(77, 6)
    const usdcPrice1 = precision.price(1) // 1$
    const oracle1 = [{ token: usdcAddr, minPrice: usdcPrice1, maxPrice: usdcPrice1 }]

    await expect(
      handleMint(fixture, {
        oracle: oracle1,
        stakeToken: xUsd,
        requestToken: usdc,
        requestTokenAmount: mintUsdtAmount,
        minStakeAmount: mintUsdtAmount,
      }),
    ).to.be.reverted
  })

  it('Case1: Mint xUsd by USDC, Oracle Price Fixed/Single User', async function () {
    const stakeToken = await ethers.getContractAt('StakeToken', xUsd)
    const preTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const preVaultBalance = BigInt(await usdc.balanceOf(lpVaultAddr))
    const preMarketBalance = BigInt(await usdc.balanceOf(xUsd))
    const preStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))

    const requestTokenAmount = precision.token(100, 6)

    const tokenPrice = precision.price(1)
    const oracle = [{ token: usdcAddr, minPrice: tokenPrice, maxPrice: tokenPrice }]

    await handleMint(fixture, {
      oracle: oracle,
      stakeToken: xUsd,
      requestToken: usdc,
      requestTokenAmount: requestTokenAmount,
    })

    const nextTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await usdc.balanceOf(lpVaultAddr))
    const nextMarketBalance = BigInt(await usdc.balanceOf(xUsd))
    const nextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))

    // config
    const usdPoolConfig = await configFacet.getUsdPoolConfig()
    const usdMintFeeRate = usdPoolConfig.mintFeeRate

    const poolInfo = await poolFacet.getUsdPool()

    const mintFee = precision.mulRate(requestTokenAmount, usdMintFeeRate)

    const realMintTokenAmount = requestTokenAmount - mintFee

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(requestTokenAmount).to.equals(nextMarketBalance - preMarketBalance)
    expect(requestTokenAmount).to.equals(preTokenBalance - nextTokenBalance)

    // xToken amount
    expect(realMintTokenAmount).to.equals(nextStakeTokenBalance - preStakeTokenBalance)

    // pool
    expect(realMintTokenAmount).to.equals(poolInfo.stableTokenBalances[0].amount)
    expect(0).to.equals(poolInfo.stableTokenBalances[0].holdAmount)
    expect(0).to.equals(poolInfo.stableTokenBalances[0].unsettledAmount)

    // Staking Account
    const xUsdAmount = await stakingAccountFacet.getAccountUsdPoolAmount(user0.address)
    expect(realMintTokenAmount).to.be.equals(xUsdAmount)
  })

  it('Case2: Multi Mint xUsd by USDC, Oracle Price Fixed/Single User', async function () {
    const stakeToken = await ethers.getContractAt('StakeToken', xUsd)
    const preTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const preVaultBalance = BigInt(await usdc.balanceOf(lpVaultAddr))
    const preMarketBalance = BigInt(await usdc.balanceOf(xUsd))
    const preStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))

    const singleMintTokenAmount = precision.token(60, 6)
    const requestTokenAmount = precision.token(3 * 60, 6)

    const tokenPrice = precision.price(1)
    const oracle = [{ token: usdcAddr, minPrice: tokenPrice, maxPrice: tokenPrice }]

    await handleMint(fixture, {
      oracle: oracle,
      stakeToken: xUsd,
      requestToken: usdc,
      requestTokenAmount: singleMintTokenAmount,
    })
    await handleMint(fixture, {
      oracle: oracle,
      stakeToken: xUsd,
      requestToken: usdc,
      requestTokenAmount: singleMintTokenAmount,
    })
    await handleMint(fixture, {
      oracle: oracle,
      stakeToken: xUsd,
      requestToken: usdc,
      requestTokenAmount: singleMintTokenAmount,
    })

    const nextTokenBalance = BigInt(await usdc.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await usdc.balanceOf(lpVaultAddr))
    const nextMarketBalance = BigInt(await usdc.balanceOf(xUsd))
    const nextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))

    const poolInfo = await poolFacet.getUsdPool()
    // config
    const usdPoolConfig = await configFacet.getUsdPoolConfig()
    const usdMintFeeRate = usdPoolConfig.mintFeeRate

    const mintFee = precision.mulRate(requestTokenAmount, usdMintFeeRate)

    const realMintTokenAmount = requestTokenAmount - mintFee

    // vault & user token amount
    expect(0).to.equals(nextVaultBalance - preVaultBalance)
    expect(requestTokenAmount).to.equals(nextMarketBalance - preMarketBalance)
    expect(requestTokenAmount).to.equals(preTokenBalance - nextTokenBalance)

    // xtoken amount
    expect(realMintTokenAmount).to.equals(nextStakeTokenBalance - preStakeTokenBalance)

    // pool
    expect(realMintTokenAmount).to.equals(poolInfo.stableTokenBalances[0].amount)
    expect(0).to.equals(poolInfo.stableTokenBalances[0].holdAmount)
    expect(0).to.equals(poolInfo.stableTokenBalances[0].unsettledAmount)

    // Staking Account
    const xUsdAmount = await stakingAccountFacet.getAccountUsdPoolAmount(user0.address)
    expect(realMintTokenAmount).to.be.equals(xUsdAmount)
  })

 
})
