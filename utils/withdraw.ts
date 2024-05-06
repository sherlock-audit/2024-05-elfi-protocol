import _ from 'lodash'
import { ethers } from 'hardhat'
import { WITHDRAW_ID_KEY } from './constants'

export async function createWithdraw(fixture, overrides: any = {}) {
  const { accountFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { weth } = fixture.tokens

  const account = overrides.account || user0
  const token = overrides.token || weth
  const amount = overrides.amount || 0
  const tx = await accountFacet.connect(account).createWithdrawRequest(await token.getAddress(), amount)
  await tx.wait()
}

export async function executeWithdraw(fixture, overrides: any = {}) {
  const { accountFacet } = fixture.contracts
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
  const tx = await accountFacet.connect(user3).executeWithdraw(requestId, oracles)
  await tx.wait()
}

export async function handleWithdraw(fixture, overrides: any = {}) {
  const { marketFacet } = fixture.contracts
  const createRequest = await createWithdraw(fixture, overrides)
  const requestId = await marketFacet.getLastUuid(WITHDRAW_ID_KEY)
  const oraclePrices = overrides.oracle || [{}]

  const executeRequest = await executeWithdraw(fixture, { requestId: requestId, oracle: oraclePrices })
  return { createRequest, executeRequest }
}
