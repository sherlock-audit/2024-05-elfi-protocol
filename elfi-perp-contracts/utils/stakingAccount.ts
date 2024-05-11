import { IStakingAccount } from 'types'

export const stakingAccount = {
  getAccountCollateralAmount(account: IStakingAccount.TokenBalanceStruct, token: string) {
    for (let i in account.collateralTokens) {
      if (account.collateralTokens[i] == token) {
        return BigInt(account.collateralAmounts[i])
      }
    }
    return BigInt(0)
  },

  getAccountCollateralLiability(account: IStakingAccount.TokenBalanceStruct, token: string) {
    for (let i in account.collateralTokens) {
      if (account.collateralTokens[i] == token) {
        return BigInt(account.collateralStakeLiability[i])
      }
    }
    return BigInt(0)
  },
}
