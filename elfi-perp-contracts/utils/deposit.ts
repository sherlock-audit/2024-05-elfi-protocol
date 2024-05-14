import { ethers } from 'hardhat'

export async function deposit(fixture, overrides: any = {}) {
  const { accountFacet } = fixture.contracts
  const { user0 } = fixture.accounts
  const { weth } = fixture.tokens
  const { diamondAddr } = fixture.addresses

  const account = overrides.account || user0
  const token = overrides.token || weth
  const amount = overrides.amount || 0
  const isNativeToken = overrides.isNativeToken || false
  if (isNativeToken) {
    const tx = await accountFacet.connect(account).deposit(ethers.ZeroAddress, amount, {
      value: amount,
    })
    await tx.wait()
  } else {
    token.connect(account).approve(diamondAddr, amount)
    const tx = await accountFacet.connect(account).deposit(await token.getAddress(), amount)
    await tx.wait()
  }
}
