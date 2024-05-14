import { CLAIM_ID_KEY } from './constants'
import { precision } from './precision'
import { oracles } from './oracles'
import { Fixture } from '@test/deployFixture'

export async function createClaimRewards(fixture: Fixture, overrides: any = {}) {
  const { feeFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { usdc } = fixture.tokens
  const account = overrides.account || user0

  const token = overrides.claimUsdToken || usdc
  const executionFee = overrides.executionFee || precision.token(2, 16)
  const tx = await feeFacet
    .connect(account)
    .createClaimRewards(await token.getAddress(), executionFee, { value: executionFee })
  await tx.wait()
}

export async function executeClaimRewards(fixture: Fixture, overrides: any = {}) {
  const { feeFacet } = fixture.contracts
  const { user3 } = fixture.accounts

  const requestId = overrides.requestId || 0
  const oraclePrices = overrides.oracle || []

  const oracle = oracles.format(oraclePrices)
  const tx = await feeFacet.connect(user3).executeClaimRewards(requestId, oracle)
  await tx.wait()
}

export async function handleClaimRewards(fixture: Fixture, overrides: any = {}) {
  const { marketFacet } = fixture.contracts
  const createRequest = await createClaimRewards(fixture, overrides)
  const requestId = await marketFacet.getLastUuid(CLAIM_ID_KEY)
  const oraclePrices = overrides.oracle || []

  const executeRequest = await executeClaimRewards(fixture, { requestId, oracle: oraclePrices })
  return { createRequest, executeRequest }
}
