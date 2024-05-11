export const math = {
  formatTickSize(value: bigint, tickSize: bigint, roundUp: boolean) {
    const isMod = value % tickSize
    if (isMod == BigInt(0)) {
      return value
    } else {
      return (value / tickSize + (roundUp ? BigInt(1) : BigInt(0))) * tickSize
    }
  },
}
