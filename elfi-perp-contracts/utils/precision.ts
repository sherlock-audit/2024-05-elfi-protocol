export const precision = {
  token(value: number | string | bigint, decimal = 18) {
    return BigInt(Math.pow(10, decimal)) * BigInt(value)
  },

  usd(value: number | string | bigint, decimal = 18) {
    return BigInt(Math.pow(10, decimal)) * BigInt(value)
  },

  rate(value: number | string | bigint, decimal = 5) {
    return BigInt(Math.pow(10, decimal)) * BigInt(value)
  },

  price(value: number | string | bigint, decimal = 8) {
    return BigInt(Math.pow(10, decimal)) * BigInt(value)
  },

  pow(value: number | string | bigint, decimal = 18) {
    return BigInt(Math.pow(10, decimal)) * BigInt(value)
  },

  mulRate(value: bigint, rate: number | string | bigint, decimal = 5) {
    return (value * BigInt(rate)) / BigInt(Math.pow(10, decimal))
  },

  divRate(value: bigint, rate: number | string | bigint, decimal = 5) {
    return (value * BigInt(Math.pow(10, decimal))) / BigInt(rate)
  },

  mulPrice(value: bigint, price: number | string | bigint, decimal = 8) {
    return (value * BigInt(price)) / BigInt(Math.pow(10, decimal))
  },

  divPrice(value: bigint, price: number | string | bigint, decimal = 8) {
    return (value * BigInt(Math.pow(10, decimal))) / BigInt(price)
  },

  tokenToUsd(value: bigint, price: number | string | bigint, decimal: number) {
    return (value * BigInt(price) * BigInt(Math.pow(10, 18 - decimal))) / BigInt(Math.pow(10, 8))
  },

  usdToToken(value: bigint, price: number | string | bigint, decimal: number = 18) {
    return (value * BigInt(Math.pow(10, 8))) / BigInt(price) / BigInt(Math.pow(10, 18 - decimal))
  },

}
