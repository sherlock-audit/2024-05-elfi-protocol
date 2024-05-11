import _ from 'lodash'
import { expect } from 'chai'
import { ORDER_ID_KEY, OrderSide, OrderType, PositionSide, StopType } from '@utils/constants'
import { precision } from '@utils/precision'
import { ethers } from 'hardhat'

export async function createOrderWrapper(fixture, overrides: any = {}) {
  const { orderFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { ethUsd } = fixture.symbols
  const { weth } = fixture.tokens
  const { diamondAddr } = fixture.addresses

  const account = overrides.account || user0
  const symbol = overrides.symbol || ethUsd
  const orderSide = overrides.orderSide || OrderSide.LONG
  const posSide = overrides.posSide || PositionSide.INCREASE
  const orderType = overrides.orderType || OrderType.MARKET
  const stopType = overrides.stopType || StopType.NONE
  const isCrossMargin = overrides.isCrossMargin || false
  const marginToken = overrides.marginToken || weth
  const qty = overrides.qty || 0
  const orderMargin = overrides.orderMargin || precision.token(0)
  const leverage = overrides.leverage || precision.rate(10, 5)
  const triggerPrice = overrides.triggerPrice || 0
  const acceptablePrice = overrides.acceptablePrice || 0
  const placeTime = overrides.placeTime || 0
  const isNativeToken = overrides.isNativeToken || false
  const executionFee = overrides.executionFee || precision.token(2, 15)

  if (isNativeToken) {
    return orderFacet.connect(account).createOrderRequest(
      {
        symbol: symbol,
        orderSide: orderSide,
        posSide: posSide,
        orderType: orderType,
        stopType: stopType,
        isCrossMargin: isCrossMargin,
        marginToken: await marginToken.getAddress(),
        qty: qty,
        orderMargin: orderMargin == 0 ? 0 : orderMargin + executionFee,
        leverage: leverage,
        triggerPrice: triggerPrice,
        acceptablePrice: acceptablePrice,
        executionFee: executionFee,
        placeTime: placeTime,
        isNativeToken: isNativeToken,
      },
      {
        value: orderMargin + executionFee,
      },
    )
  } else {
    if (!isCrossMargin && orderMargin > 0) {
      marginToken.connect(account).approve(diamondAddr, orderMargin)
    }
    return orderFacet.connect(account).createOrderRequest(
      {
        symbol: symbol,
        orderSide: orderSide,
        posSide: posSide,
        orderType: orderType,
        stopType: stopType,
        isCrossMargin: isCrossMargin,
        marginToken: await marginToken.getAddress(),
        qty: qty,
        orderMargin: orderMargin,
        leverage: leverage,
        triggerPrice: triggerPrice,
        acceptablePrice: acceptablePrice,
        executionFee: executionFee,
        placeTime: placeTime,
        isNativeToken: isNativeToken,
      },
      {
        value: executionFee,
      },
    )
  }
}

export async function createOrder(fixture, overrides: any = {}) {
  const { orderFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { ethUsd } = fixture.symbols
  const { weth } = fixture.tokens
  const { diamondAddr } = fixture.addresses

  const account = overrides.account || user0
  const symbol = overrides.symbol || ethUsd
  const orderSide = overrides.orderSide || OrderSide.LONG
  const posSide = overrides.posSide || PositionSide.INCREASE
  const orderType = overrides.orderType || OrderType.MARKET
  const stopType = overrides.stopType || StopType.NONE
  const isCrossMargin = overrides.isCrossMargin || false
  const marginToken = overrides.marginToken || weth
  const qty = overrides.qty || 0
  const orderMargin = overrides.orderMargin || precision.token(0)
  const leverage = overrides.leverage || precision.rate(10, 5)
  const triggerPrice = overrides.triggerPrice || 0
  const acceptablePrice = overrides.acceptablePrice || 0
  const placeTime = overrides.placeTime || 0
  const isNativeToken = overrides.isNativeToken || false
  const executionFee = overrides.executionFee || precision.token(2, 15)

  if (isNativeToken) {
    const tx = await orderFacet.connect(account).createOrderRequest(
      {
        symbol: symbol,
        orderSide: orderSide,
        posSide: posSide,
        orderType: orderType,
        stopType: stopType,
        isCrossMargin: isCrossMargin,
        marginToken: await marginToken.getAddress(),
        qty: qty,
        orderMargin: orderMargin == 0 ? 0 : orderMargin + executionFee,
        leverage: leverage,
        triggerPrice: triggerPrice,
        acceptablePrice: acceptablePrice,
        executionFee: executionFee,
        placeTime: placeTime,
        isNativeToken: isNativeToken,
      },
      {
        value: orderMargin + executionFee,
      },
    )
    await tx.wait()
  } else {
    if (!isCrossMargin && orderMargin > 0) {
      marginToken.connect(account).approve(diamondAddr, orderMargin)
    }
    const tx = await orderFacet.connect(account).createOrderRequest(
      {
        symbol: symbol,
        orderSide: orderSide,
        posSide: posSide,
        orderType: orderType,
        stopType: stopType,
        isCrossMargin: isCrossMargin,
        marginToken: await marginToken.getAddress(),
        qty: qty,
        orderMargin: orderMargin,
        leverage: leverage,
        triggerPrice: triggerPrice,
        acceptablePrice: acceptablePrice,
        executionFee: executionFee,
        placeTime: placeTime,
        isNativeToken: isNativeToken,
      },
      {
        value: executionFee,
      },
    )
    await tx.wait()
  }
}

export async function executeOrder(fixture, overrides: any = {}) {
  const { orderFacet } = fixture.contracts
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

  const tx = await orderFacet.connect(user3).executeOrder(requestId, oracles)
  await tx.wait()
}

export async function cancelOrder(fixture, overrides: any = {}) {
  const { orderFacet } = fixture.contracts
  const { user3 } = fixture.accounts

  const requestId = overrides.requestId || 0
  const reasonCode = overrides.reasonCode || ethers.encodeBytes32String('0x00')

  const tx = await orderFacet.connect(user3).cancelOrder(requestId, reasonCode)
  await tx.wait()
}

export async function handleOrder(fixture, overrides: any = {}) {
  const { marketFacet } = fixture.contracts
  const createRequest = await createOrder(fixture, overrides)
  const requestId = await marketFacet.getLastUuid(ORDER_ID_KEY)
  const oraclePrices = overrides.oracle || [{}]

  const executeRequest = await executeOrder(fixture, { requestId: requestId, oracle: oraclePrices })
  return { createRequest, executeRequest }
}
