import _ from 'lodash'
import { expect } from 'chai'
import { REDEEM_ID_KEY } from '@utils/constants'
import { precision } from '@utils/precision'
import { ethers } from 'hardhat'

export async function createRedeem(fixture, overrides: any = {}) {
  const { stakeFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { xEth } = fixture.pools
  const { weth } = fixture.tokens

  const account = overrides.account || user0
  const receiver = overrides.receiver || account.address
  const stakeToken = overrides.stakeToken || xEth
  const redeemToken = overrides.redeemToken || weth
  const unStakeAmount = overrides.unStakeAmount || precision.token(0)
  const minRedeemAmount = overrides.minRedeemAmount || precision.token(0)
  const executionFee = overrides.executionFee || precision.token(2, 15)

  const tx = await stakeFacet.connect(account).createRedeemStakeTokenRequest({
    receiver: receiver,
    stakeToken: stakeToken,
    redeemToken: await redeemToken.getAddress(),
    unStakeAmount: unStakeAmount,
    minRedeemAmount: minRedeemAmount,
    executionFee: executionFee
  }, {
    value: executionFee
  })

  await tx.wait()
}

export async function createRedeemWrapper(fixture, overrides: any = {}) {
  const { stakeFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { xEth } = fixture.pools
  const { weth } = fixture.tokens

  const account = overrides.account || user0
  const receiver = overrides.receiver || account.address
  const stakeToken = overrides.stakeToken || xEth
  const redeemToken = overrides.redeemToken || weth
  const unStakeAmount = overrides.unStakeAmount || precision.token(0)
  const minRedeemAmount = overrides.minRedeemAmount || precision.token(0)
  const executionFee = overrides.executionFee || precision.token(2, 15)

  return stakeFacet.connect(account).createRedeemStakeTokenRequest({
    receiver: receiver,
    stakeToken: stakeToken,
    redeemToken: await redeemToken.getAddress(),
    unStakeAmount: unStakeAmount,
    minRedeemAmount: minRedeemAmount,
    executionFee: executionFee
  }, {
    value: executionFee
  })
}

export async function executeRedeem(fixture, overrides: any = {}) {
  const { stakeFacet } = fixture.contracts
  const { user3 } = fixture.accounts

  const requestId = overrides.requestId || 0
  const oraclePrices = overrides.oracle || [{}]

  const oracles = _.map(oraclePrices, function (prices) {
    return {
      token: prices.token,
      targetToken: prices.targetToken || ethers.ZeroAddress,
      minPrice: prices.minPrice,
      maxPrice: prices.maxPrice,
    }
  })

  const tx = await stakeFacet.connect(user3).executeRedeemStakeToken(requestId, oracles)
  await tx.wait()
}

export async function handleRedeem(fixture, overrides: any = {}) {
  const { marketFacet } = fixture.contracts
  const createRequest = await createRedeem(fixture, overrides)
  const requestId = await marketFacet.getLastUuid(REDEEM_ID_KEY)
  const oraclePrices = overrides.oracle || [{}]

  const executeRequest = await executeRedeem(fixture, { requestId: requestId, oracle: oraclePrices })
  return { createRequest, executeRequest }
}
