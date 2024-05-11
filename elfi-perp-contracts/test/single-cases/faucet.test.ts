import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { precision } from '@utils/precision'
import { FaucetFacet, MockToken } from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { ethers } from 'hardhat'

describe('Faucet Test', function () {
  let fixture: Fixture
  let faucetFacet: FaucetFacet

  let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner, user3: HardhatEthersSigner
  let diamondAddr: string,
    tradeVaultAddr: string,
    wbtcAddr: string,
    wethAddr: string,
    usdtAddr: string,
    usdcAddr: string,
    daiAddr: string
  let btcUsd: string, ethUsd: string, xBtc: string, xEth: string, xUsd: string
  let wbtc: MockToken, weth: MockToken, usdt: MockToken, usdc: MockToken, dai: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ diamondAddr } = fixture.addresses)
    ;({ faucetFacet } = fixture.contracts)
    ;({ user0, user1, user2, user3 } = fixture.accounts)
    ;({ btcUsd, ethUsd } = fixture.symbols)
    ;({ xBtc, xEth, xUsd } = fixture.pools)
    ;({ wbtc, weth, usdc } = fixture.tokens)
    ;({ diamondAddr, tradeVaultAddr } = fixture.addresses)
  })

  it('Case0', async function () {
    const tx = await user0.sendTransaction({
      to: diamondAddr,
      value: ethers.parseEther('10'),
    })

    await tx.wait()
    const ethTokenBalance0 = BigInt(await ethers.provider.getBalance(user0.address))
    console.log('user0 ethTokenBalance0', ethTokenBalance0)
    const ethTokenBalance1 = BigInt(await ethers.provider.getBalance(user1.address))
    console.log('user1 ethTokenBalance1', ethTokenBalance1)
    const ethTokenBalance2 = BigInt(await ethers.provider.getBalance(diamondAddr))
    console.log('diamondAddr ethTokenBalance2', ethTokenBalance2)
    faucetFacet.connect(user0).requestTokens({
      account: user1,
      mockTokens: [],
      mintAmounts: [],
      ethAmount: precision.token(7),
    })
    const ethTokenBalance0_1 = BigInt(await ethers.provider.getBalance(user0.address))
    console.log('user0 ethTokenBalance0_1', ethTokenBalance0_1)
    const ethTokenBalance1_1 = BigInt(await ethers.provider.getBalance(user1.address))
    console.log('user1 ethTokenBalance1_1', ethTokenBalance1_1)
    const ethTokenBalance2_1 = BigInt(await ethers.provider.getBalance(diamondAddr))
    console.log('diamondAddr ethTokenBalance2_1', ethTokenBalance2_1)
  })
})
