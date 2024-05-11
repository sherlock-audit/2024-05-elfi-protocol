import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { precision } from '@utils/precision'
import { handleMint } from '@utils/mint'
import { FeeFacet, LpVault, MarketFacet, ConfigFacet, MockToken, PoolFacet, StakingAccountFacet } from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { ethers } from 'hardhat'
import { Contract } from 'ethers'
import { createRedeemWrapper, handleRedeem } from '@utils/redeem'
import { pool } from '@utils/pool'

describe('Redeem xUsd Test', function () {
  let fixture: Fixture
  let poolFacet: PoolFacet, stakingAccountFacet: StakingAccountFacet, feeFacet: FeeFacet
  let configFacet: ConfigFacet
  let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner, user3: HardhatEthersSigner
  let btcAddr: string, ethAddr: string, usdcAddr: string
  let xUsd: string
  let wbtc: MockToken, weth: MockToken, usdc: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ poolFacet, stakingAccountFacet, feeFacet, configFacet } = fixture.contracts)
    ;({ user0, user1, user2, user3 } = fixture.accounts)
    ;({ xUsd } = fixture.pools)
    ;({ wbtc, weth, usdc } = fixture.tokens)
    btcAddr = await wbtc.getAddress()
    ethAddr = await weth.getAddress()
    usdcAddr = await usdc.getAddress()

    const usdtTokenPrice = precision.price(1)
    const usdcTokenPrice = precision.price(101, 6)
    const daiTokenPrice = precision.price(9, 7)
    const usdOracle = [{ token: usdcAddr, minPrice: usdcTokenPrice, maxPrice: usdcTokenPrice }]

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

  it('Case0: Redeem xUsd errors', async function () {
    // redeem amount zero
    await expect(createRedeemWrapper(fixture, { stakeToken: xUsd, redeemToken: usdc, unStakeAmount: 0 })).to.be.reverted

    // receiver error
    await expect(
      createRedeemWrapper(fixture, {
        stakeToken: xUsd,
        redeemToken: usdc,
        unStakeAmount: precision.token(10),
        receiver: ethers.ZeroAddress,
      }),
    ).to.be.reverted

    // redeem token error
    await expect(
      createRedeemWrapper(fixture, { stakeToken: xUsd, redeemToken: wbtc, unStakeAmount: precision.token(10) }),
    ).to.be.reverted

    // redeem with no balance
    await expect(
      createRedeemWrapper(fixture, {
        stakeToken: xUsd,
        redeemToken: usdc,
        account: user3,
        unStakeAmount: precision.token(10),
      }),
    ).to.be.reverted
  })

  it('Case1: Redeem USDC from xUsd Success, Once', async function () {
    const stakeToken = await ethers.getContractAt('StakeToken', xUsd)
    const redeemToken = usdc
    const redeemTokenAddr = usdcAddr

    const preStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))
    const preTokenBalance = BigInt(await redeemToken.balanceOf(user0.address))
    const preVaultBalance = BigInt(await redeemToken.balanceOf(xUsd))
    const preStakingBalance = await stakingAccountFacet.getAccountUsdPoolAmount(user0.address)
    const prePoolInfo = await poolFacet.getUsdPool()

    // config
    const usdPoolConfig = await configFacet.getUsdPoolConfig()
    const redeemFeeRate = usdPoolConfig.redeemFeeRate

    const unStakeAmount = precision.token(100, 6) //100 xUsd
    const usdtPrice = precision.price(9, 7) // 0.9$
    const usdcPrice = precision.price(1) // 1$
    const daiPrice = precision.price(1) // 1$

    await handleRedeem(fixture, {
      stakeToken: xUsd,
      redeemToken: usdc,
      unStakeAmount: unStakeAmount,
      oracle: [{ token: usdcAddr, minPrice: usdcPrice, maxPrice: usdcPrice }],
    })

    const stableTokens = prePoolInfo.stableTokens
    var poolValue = BigInt(0)
    for (let i in stableTokens) {
      if (stableTokens[i] == usdcAddr) {
        poolValue += precision.mulPrice(prePoolInfo.stableTokenBalances[i].amount * BigInt(10 ** 12), usdcPrice)
      }
    }

    const redeemTokenAmountOrigin =
      precision.divPrice((unStakeAmount * poolValue) / prePoolInfo.totalSupply, usdcPrice) / BigInt(10 ** 12)
    const redeemFee = precision.mulRate(redeemTokenAmountOrigin, redeemFeeRate)

    const redeemTokenAmount = redeemTokenAmountOrigin - redeemFee

    // wallet/xToken amount
    const nextStakeTokenBalance = BigInt(await stakeToken.balanceOf(user0.address))
    const nextTokenBalance = BigInt(await redeemToken.balanceOf(user0.address))
    const nextVaultBalance = BigInt(await redeemToken.balanceOf(xUsd))

    expect(-unStakeAmount).to.equals(nextStakeTokenBalance - preStakeTokenBalance)
    expect(redeemTokenAmount).to.equals(nextTokenBalance - preTokenBalance)
    expect(-redeemTokenAmount).to.equals(nextVaultBalance - preVaultBalance)

    const nextPoolInfo = await poolFacet.getUsdPool()

    // pool
    expect(redeemTokenAmountOrigin).to.equals(
      pool.getUsdPoolStableTokenAmount(prePoolInfo, usdcAddr) -
        pool.getUsdPoolStableTokenAmount(nextPoolInfo, usdcAddr),
    )

    // Staking Account
    const nextStakingBalance = await stakingAccountFacet.getAccountUsdPoolAmount(user0.address)
    expect(-unStakeAmount).to.be.equals(nextStakingBalance - preStakingBalance)
  })
})
