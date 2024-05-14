import { ethers } from 'hardhat'

export const WITHDRAW_ID_KEY = ethers.keccak256(ethers.toUtf8Bytes('WITHDRAW_ID_KEY'))

export const MINT_ID_KEY = ethers.keccak256(ethers.toUtf8Bytes('MINT_ID_KEY'))

export const REDEEM_ID_KEY = ethers.keccak256(ethers.toUtf8Bytes('REDEEM_ID_KEY'))

export const ORDER_ID_KEY = ethers.keccak256(ethers.toUtf8Bytes('ORDER_ID_KEY'))

export const UPDATE_MARGIN_ID_KEY = ethers.keccak256(ethers.toUtf8Bytes('UPDATE_MARGIN_ID_KEY'))

export const UPDATE_LEVERAGE_ID_KEY = ethers.keccak256(ethers.toUtf8Bytes('UPDATE_LEVERAGE_ID_KEY'))

export const CLAIM_ID_KEY = ethers.keccak256(ethers.toUtf8Bytes('CLAIM_ID_KEY'))

export const ROLE_ADMIN = 'ADMIN'

export const ROLE_CONFIG = 'CONFIG'

export const ROLE_KEEPER = 'KEEPER'

export enum PositionSide {
  NONE,
  INCREASE,
  DECREASE,
}

export enum OrderSide {
  NONE,
  LONG,
  SHORT,
}

export enum OrderType {
  NONE,
  MARKET,
  LIMIT,
  STOP,
  LIQUIDATION,
}

export enum StopType {
  NONE,
  STOP_LOSS,
  TAKE_PROFIT,
}
