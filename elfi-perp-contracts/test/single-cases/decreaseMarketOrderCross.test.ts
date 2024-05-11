import { expect } from 'chai'
import { Fixture, deployFixture } from '@test/deployFixture'
import { precision } from '@utils/precision'
import {
  AccountFacet,
  ConfigFacet,
  FeeFacet,
  MarketFacet,
  MockToken,
  OrderFacet,
  PoolFacet,
  PositionFacet,
  TradeVault,
} from 'types'
import { HardhatEthersSigner } from '@nomicfoundation/hardhat-ethers/signers'
import { Contract } from 'ethers'
import { handleOrder } from '@utils/order'
import { handleMint } from '@utils/mint'
import { OrderSide, PositionSide } from '@utils/constants'
import { account } from '@utils/account'
import { deposit } from '@utils/deposit'
import { ethers } from 'hardhat'
import { oracles } from '@utils/oracles'

describe('Decrease Market Order Cross Process', function () {
  let fixture: Fixture
  let tradeVault: TradeVault,
    marketFacet: MarketFacet,
    poolFacet: PoolFacet,
    accountFacet: AccountFacet,
    positionFacet: PositionFacet,
    feeFacet: FeeFacet,
    configFacet: ConfigFacet
  let user0: HardhatEthersSigner, user1: HardhatEthersSigner, user2: HardhatEthersSigner
  let tradeVaultAddr: string,
    portfolioVaultAddr: string,
    wbtcAddr: string,
    wethAddr: string,
    usdcAddr: string
  let btcUsd: string, ethUsd: string, xBtc: string, xEth: string, xUsd: string
  let wbtc: MockToken, weth: MockToken, usdc: MockToken

  beforeEach(async () => {
    fixture = await deployFixture()
    ;({ tradeVault, marketFacet, poolFacet, accountFacet, positionFacet, feeFacet, configFacet } = fixture.contracts)
    ;({ user0, user1, user2 } = fixture.accounts)
    ;({ btcUsd, ethUsd } = fixture.symbols)
    ;({ xBtc, xEth, xUsd } = fixture.pools)
    ;({ wbtc, weth, usdc } = fixture.tokens)
    ;({ tradeVaultAddr, portfolioVaultAddr } = fixture.addresses)
    wbtcAddr = await wbtc.getAddress()
    wethAddr = await weth.getAddress()
    usdcAddr = await usdc.getAddress()

    const btcTokenPrice = precision.price(25000)
    const btcOracle = [{ token: wbtcAddr, minPrice: btcTokenPrice, maxPrice: btcTokenPrice }]
    await handleMint(fixture, {
      stakeToken: xBtc,
      requestToken: wbtc,
      requestTokenAmount: precision.token(100),
      oracle: btcOracle,
    })

    const ethTokenPrice = precision.price(1600)
    const ethOracle = [{ token: wethAddr, minPrice: ethTokenPrice, maxPrice: ethTokenPrice }]
    await handleMint(fixture, {
      requestTokenAmount: precision.token(1000),
      oracle: ethOracle,
    })

    const usdtTokenPrice = precision.price(1)
    const usdcTokenPrice = precision.price(101, 6)
    const daiTokenPrice = precision.price(99, 6)
    const usdOracle = [
      { token: usdcAddr, minPrice: usdcTokenPrice, maxPrice: usdcTokenPrice },
    ]

    await handleMint(fixture, {
      requestTokenAmount: precision.token(100000, 6),
      stakeToken: xUsd,
      requestToken: usdc,
      oracle: usdOracle,
    })

  })

})
