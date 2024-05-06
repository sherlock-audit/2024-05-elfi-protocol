import { UPDATE_LEVERAGE_ID_KEY, UPDATE_MARGIN_ID_KEY } from '@utils/constants'
import { ethers } from 'hardhat'
import _ from 'lodash'
import { precision } from './precision'

export async function createUpdateMargin(fixture, overrides: any = {}) {
  const { positionFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { weth } = fixture.tokens
  const { diamondAddr } = fixture.addresses

  const account = overrides.account || user0
  const positionKey = overrides.positionKey
  const isAdd = overrides.isAdd
  const isNativeToken = overrides.isNativeToken || false
  const isCrossMargin = overrides.isCrossMargin || false
  const marginToken = overrides.marginToken || weth
  const updateMarginAmount = overrides.updateMarginAmount
  const executionFee = overrides.executionFee || precision.token(2, 15)

  if (isNativeToken) {
    const tx = await positionFacet.connect(account).createUpdatePositionMarginRequest(
      {
        positionKey: positionKey,
        isAdd: isAdd,
        isNativeToken: isNativeToken,
        isCrossMargin: isCrossMargin,
        marginToken: await marginToken.getAddress(),
        updateMarginAmount: updateMarginAmount == 0 ? 0 : updateMarginAmount + executionFee,
        executionFee: executionFee,
      },
      {
        value: updateMarginAmount + executionFee,
      },
    )
    await tx.wait()
  } else {
    if (isAdd) {
      marginToken.connect(account).approve(diamondAddr, updateMarginAmount)
    }
    const tx = await positionFacet.connect(account).createUpdatePositionMarginRequest(
      {
        positionKey: positionKey,
        isAdd: isAdd,
        isNativeToken: isNativeToken,
        isCrossMargin: isCrossMargin,
        marginToken: await marginToken.getAddress(),
        updateMarginAmount: updateMarginAmount,
        executionFee: executionFee,
      },
      {
        value: executionFee,
      },
    )
    await tx.wait()
  }
}

export async function executeUpdateMargin(fixture, overrides: any = {}) {
  const { positionFacet } = fixture.contracts
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

  const tx = await positionFacet.connect(user3).executeUpdatePositionMarginRequest(requestId, oracles)
  await tx.wait()
}

export async function handleUpdateMargin(fixture, overrides: any = {}) {
  const { marketFacet } = fixture.contracts
  const createRequest = await createUpdateMargin(fixture, overrides)
  const requestId = await marketFacet.getLastUuid(UPDATE_MARGIN_ID_KEY)
  const oraclePrices = overrides.oracle || [{}]
  const executeRequest = await executeUpdateMargin(fixture, { requestId: requestId, oracle: oraclePrices })
  return { createRequest, executeRequest }
}

export async function createUpdateLeverage(fixture, overrides: any = {}) {
  const { positionFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { ethUsd } = fixture.symbols
  const { diamondAddr } = fixture.addresses
  const { weth } = fixture.tokens

  const account = overrides.account || user0
  const symbol = overrides.symbol || ethUsd
  const isLong = overrides.isLong
  const isNativeToken = overrides.isNativeToken || false
  const isCrossMargin = overrides.isCrossMargin || false
  const leverage = overrides.leverage || precision.rate(10)
  const marginToken = overrides.marginToken || ethers.ZeroAddress
  const addMarginAmount = overrides.addMarginAmount
  const executionFee = overrides.executionFee || precision.token(2, 15)

  if (isNativeToken) {
    const tx = await positionFacet.connect(account).createUpdateLeverageRequest(
      {
        symbol: symbol,
        isLong: isLong,
        isNativeToken: isNativeToken,
        leverage: leverage,
        marginToken: await marginToken.getAddress(),
        addMarginAmount: addMarginAmount == 0 ? 0 : addMarginAmount + executionFee,
        executionFee: executionFee,
        isCrossMargin: isCrossMargin
      },
      {
        value: addMarginAmount + executionFee,
      },
    )
    await tx.wait()
  } else {
    if (addMarginAmount > 0) {
      marginToken.connect(account).approve(diamondAddr, addMarginAmount)
    }
    const tx = await positionFacet.connect(account).createUpdateLeverageRequest(
      {
        symbol: symbol,
        isLong: isLong,
        isNativeToken: isNativeToken,
        leverage: leverage,
        marginToken: await marginToken.getAddress(),
        addMarginAmount: addMarginAmount,
        executionFee: executionFee,
        isCrossMargin: isCrossMargin
      },
      {
        value: executionFee,
      },
    )
    await tx.wait()
  }
}

export async function executeUpdateLeverage(fixture, overrides: any = {}) {
  const { positionFacet } = fixture.contracts
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

  const tx = await positionFacet.connect(user3).executeUpdateLeverageRequest(requestId, oracles)
  await tx.wait()
}

export async function handleUpdateLeverage(fixture, overrides: any = {}) {
  const { marketFacet } = fixture.contracts
  const createRequest = await createUpdateLeverage(fixture, overrides)
  const requestId = await marketFacet.getLastUuid(UPDATE_LEVERAGE_ID_KEY)
  const oraclePrices = overrides.oracle || [{}]

  const executeRequest = await executeUpdateLeverage(fixture, { requestId: requestId, oracle: oraclePrices })
  return { createRequest, executeRequest }
}
