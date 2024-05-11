import _ from 'lodash'
import { MINT_ID_KEY } from '@utils/constants'
import { precision } from '@utils/precision'
import { ethers } from 'hardhat'
import { Fixture } from '@test/deployFixture'

export async function createMint(fixture, overrides: any = {}) {
  const { stakeFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { xEth } = fixture.pools
  const { weth } = fixture.tokens
  const { diamondAddr } = fixture.addresses

  const account = overrides.account || user0
  const receiver = overrides.receiver || account.address
  const stakeToken = overrides.stakeToken || xEth
  const requestToken = overrides.requestToken || weth
  const requestTokenAmount = overrides.requestTokenAmount || precision.token(0)
  let walletRequestTokenAmount: BigInt = overrides.walletRequestTokenAmount || requestTokenAmount
  const minStakeAmount = overrides.minStakeAmount || precision.token(0)
  const isCollateral = overrides.isCollateral || false
  const isNativeToken = overrides.isNativeToken || false
  const executionFee = overrides.executionFee || precision.token(2, 15)

  walletRequestTokenAmount =
    overrides.walletRequestTokenAmount !== undefined ? overrides.walletRequestTokenAmount : walletRequestTokenAmount

  if (isNativeToken) {
    const tx = await stakeFacet.connect(account).createMintStakeTokenRequest(
      {
        receiver: receiver,
        stakeToken: stakeToken,
        requestToken: await requestToken.getAddress(),
        requestTokenAmount: requestTokenAmount,
        walletRequestTokenAmount: walletRequestTokenAmount == BigInt(0) ? 0 : walletRequestTokenAmount + executionFee,
        minStakeAmount: minStakeAmount,
        isCollateral: isCollateral,
        isNativeToken: isNativeToken,
        executionFee: executionFee,
      },
      {
        value: walletRequestTokenAmount + executionFee,
      },
    )
    await tx.wait()
  } else {
    requestToken.connect(account).approve(diamondAddr, walletRequestTokenAmount)
    return stakeFacet.connect(account).createMintStakeTokenRequest(
      {
        receiver: receiver,
        stakeToken: stakeToken,
        requestToken: await requestToken.getAddress(),
        requestTokenAmount: requestTokenAmount,
        walletRequestTokenAmount: walletRequestTokenAmount,
        minStakeAmount: minStakeAmount,
        isCollateral: isCollateral,
        isNativeToken: isNativeToken,
        executionFee: executionFee,
      },
      {
        value: executionFee,
      },
    )
  }
}

export async function createMintWrapper(fixture, overrides: any = {}) {
  const { stakeFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { xEth } = fixture.pools
  const { weth } = fixture.tokens
  const { diamondAddr } = fixture.addresses

  const account = overrides.account || user0
  const receiver = overrides.receiver || account.address
  const stakeToken = overrides.stakeToken || xEth
  const requestToken = overrides.requestToken || weth
  const requestTokenAmount = overrides.requestTokenAmount || precision.token(0)
  const walletRequestTokenAmount = overrides.walletRequestTokenAmount || requestTokenAmount
  const minStakeAmount = overrides.minStakeAmount || precision.token(0)
  const isCollateral = overrides.isCollateral || false
  const isNativeToken = overrides.isNativeToken || false
  const executionFee = overrides.executionFee || precision.token(2, 15)

  if (isNativeToken) {
    return stakeFacet.connect(account).createMintStakeTokenRequest(
      {
        receiver: receiver,
        stakeToken: stakeToken,
        requestToken: await requestToken.getAddress(),
        requestTokenAmount: requestTokenAmount,
        walletRequestTokenAmount: walletRequestTokenAmount == 0 ? 0 : walletRequestTokenAmount + executionFee,
        minStakeAmount: minStakeAmount,
        isCollateral: isCollateral,
        isNativeToken: isNativeToken,
        executionFee: executionFee,
      },
      {
        value: walletRequestTokenAmount + executionFee,
      },
    )
  } else {
    requestToken.connect(account).approve(diamondAddr, walletRequestTokenAmount)
    return stakeFacet.connect(account).createMintStakeTokenRequest(
      {
        receiver: receiver,
        stakeToken: stakeToken,
        requestToken: await requestToken.getAddress(),
        requestTokenAmount: requestTokenAmount,
        walletRequestTokenAmount: walletRequestTokenAmount,
        minStakeAmount: minStakeAmount,
        isCollateral: isCollateral,
        isNativeToken: isNativeToken,
        executionFee: executionFee,
      },
      {
        value: executionFee,
      },
    )
  }
}

export async function executeMint(fixture, overrides: any = {}) {
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

  const tx = await stakeFacet.connect(user3).executeMintStakeToken(requestId, oracles)
  await tx.wait()
}

export async function handleMint(fixture: Fixture, overrides: any = {}) {
  const { marketFacet } = fixture.contracts
  const createRequest = await createMint(fixture, overrides)
  const requestId = await marketFacet.getLastUuid(MINT_ID_KEY)
  const oraclePrices = overrides.oracle || [{}]

  const executeRequest = await executeMint(fixture, { requestId: requestId, oracle: oraclePrices })
  return { createRequest, executeRequest }
}
