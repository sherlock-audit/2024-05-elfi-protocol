import { IAccount, OrderFacet } from 'types'

export const account = {
  getAccountTokenBalance(account: IAccount.AccountInfoStruct, token: string) {
    for (let i in account.tokens) {
      if (account.tokens[i] == token) {
        return account.tokenBalances[i]
      }
    }
  },

  getAccountTokenAmount(account: IAccount.AccountInfoStruct, token: string) {
    for (let i in account.tokens) {
      if (account.tokens[i] == token) {
        return BigInt(account.tokenBalances[i].amount)
      }
    }
    return BigInt(0)
  },

  getAccountTokenUsedAmount(account: IAccount.AccountInfoStruct, token: string) {
    for (let i in account.tokens) {
      if (account.tokens[i] == token) {
        return BigInt(account.tokenBalances[i].usedAmount)
      }
    }
    return BigInt(0)
  },

  // getAccountTokenBorrowingAmount(account: IAccount.AccountInfoStruct, token: string) {
  //   for (let i in account.tokens) {
  //     if (account.tokens[i] == token) {
  //       return BigInt(account.tokenBalances[i].borrowingAmount)
  //     }
  //   }
  //   return BigInt(0)
  // },

  getAccountTokenLiability(account: IAccount.AccountInfoStruct, token: string) {
    for (let i in account.tokens) {
      if (account.tokens[i] == token) {
        return BigInt(account.tokenBalances[i].liability)
      }
    }
    return BigInt(0)
  },

}
