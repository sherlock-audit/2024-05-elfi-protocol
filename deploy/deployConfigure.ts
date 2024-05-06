import _ from 'lodash'
import { ethers } from 'hardhat'
import { HardhatRuntimeEnvironment } from 'hardhat/types'
import {
  ConfigFacet,
  LpVault,
  MarketFacet,
  MarketManagerFacet,
  PoolFacet,
  PortfolioVault,
  RoleAccessControlFacet,
  TradeVault,
  Vault,
} from '../types'
import { ZeroAddress } from 'ethers'

const func = async (hre: HardhatRuntimeEnvironment) => {
  if (!['localhost', 'hardhat', 'dev', 'sepolia'].includes(hre.network.name)) {
    return
  }

  const commonConfig = await hre.elfi.getConfig()
  const marketConfig = await hre.elfi.getMarkets()
  const tokens = await hre.elfi.getTokens()
  const usdPool = await hre.elfi.getUsdPool()
  const roles = await hre.elfi.getRoles()
  const vaults = await hre.elfi.getVaults()

  const diamond = await ethers.getContract('Diamond')
  const diamondAddr = await diamond.getAddress()
  const marketManagerFacet = (await ethers.getContractAt(
    'MarketManagerFacet',
    diamondAddr,
  )) as unknown as MarketManagerFacet
  const poolFacet = (await ethers.getContractAt('PoolFacet', diamondAddr)) as unknown as PoolFacet
  const marketFacet = (await ethers.getContractAt('MarketFacet', diamondAddr)) as unknown as MarketFacet
  const roleAccessControlFacet = (await ethers.getContractAt(
    'RoleAccessControlFacet',
    diamondAddr,
  )) as unknown as RoleAccessControlFacet
  const configFacet = (await ethers.getContractAt('ConfigFacet', diamondAddr)) as unknown as ConfigFacet

  const { deployer } = await hre.getNamedAccounts()
  const wallet = await ethers.getSigner(deployer)

  console.log('config vault role start....')
  const lpVault = await ethers.getContract<LpVault>('LpVault')
  await lpVault.grantAdmin(diamondAddr)
  const tradeVault = await ethers.getContract<TradeVault>('TradeVault')
  await tradeVault.grantAdmin(diamondAddr)
  const portfolioVault = await ethers.getContract<PortfolioVault>('PortfolioVault')
  await portfolioVault.grantAdmin(diamondAddr)

  console.log('config vault role end....')

  console.log('config role start....')
  for (var i = 0; i < roles.length; i++) {
    console.log(i, '- process')
    for (var j = 0; j < roles[i].roles.length; j++) {
      if (await roleAccessControlFacet.hasRole(roles[i].account, ethers.encodeBytes32String(roles[i].roles[j]))) {
        console.log('ignore with account role exists', roles[i].roles[j])
      } else {
        await roleAccessControlFacet.grantRole(roles[i].account, ethers.encodeBytes32String(roles[i].roles[j]))
      }
    }
  }
  console.log('config role end')

  console.log('config vault start')
  await configFacet.connect(wallet).setVaultConfig({
    tradeVault: vaults.TradeVault.address,
    lpVault: vaults.LpVault.address,
    portfolioVault: vaults.PortfolioVault.address,
  })
  console.log('config vault end')

  for (var i = 0; i < marketConfig.length; i++) {
    const market = marketConfig[i]
    console.log('config market start', market.symbol.code)
    const params = {
      code: ethers.encodeBytes32String(market.symbol.code),
      stakeTokenName: market.symbol.stakeTokenName,
      indexToken: tokens[market.symbol.indexToken].address,
      baseToken: tokens[market.symbol.baseToken].address,
      baseTokenName: market.symbol.baseTokenName,
    }
    console.log(params)
    let symbolInfo = await marketFacet.getSymbol(params.code)
    if (symbolInfo.stakeToken == null || symbolInfo.stakeToken == '' || symbolInfo.stakeToken == ZeroAddress) {
      await marketManagerFacet.connect(wallet).createMarket(params)
      console.log('create market end', market.symbol.code)
      symbolInfo = await marketFacet.getSymbol(params.code)
    } else {
      console.log('ignore create market with exists', symbolInfo)
    }

    const configParams = {
      stakeToken: symbolInfo.stakeToken,
      config: {
        assetTokens: _.map(market.poolConfig.assetTokens, function (token: string) {
          if (token == 'ETH') {
            return ethers.ZeroAddress
          }

          return tokens[token].address
        }),
        baseInterestRate: market.poolConfig.borrowingBaseInterestRate,
        poolLiquidityLimit: market.poolConfig.poolLiquidityLimit,
        mintFeeRate: market.poolConfig.mintFeeRate,
        redeemFeeRate: market.poolConfig.redeemFeeRate,
        poolPnlRatioLimit: market.poolConfig.poolPnlRatioLimit,
        collateralStakingRatioLimit: market.poolConfig.collateralStakingRatioLimit,
        unsettledBaseTokenRatioLimit: market.poolConfig.unsettledBaseTokenRatioLimit,
        unsettledStableTokenRatioLimit: market.poolConfig.unsettledStableTokenRatioLimit,
        poolStableTokenRatioLimit: market.poolConfig.poolStableTokenRatioLimit,
        poolStableTokenLossLimit: market.poolConfig.poolStableTokenLossLimit,
      },
    }

    console.log('config pool start', market.symbol.code)
    console.log(configParams)
    await configFacet.connect(wallet).setPoolConfig(configParams)
    console.log('config pool end', market.symbol.code)

    const symbolConfig = {
      symbol: params.code,
      config: {
        tickSize: market.symbolConfig.tickSize,
        maxLeverage: market.symbolConfig.maxLeverage,
        openFeeRate: market.symbolConfig.openFeeRate,
        closeFeeRate: market.symbolConfig.closeFeeRate,
        maxLongOpenInterestCap: market.symbolConfig.maxLongOpenInterestCap,
        maxShortOpenInterestCap: market.symbolConfig.maxShortOpenInterestCap,
        longShortRatioLimit: market.symbolConfig.longShortRatioLimit,
        longShortOiBottomLimit: market.symbolConfig.longShortOiBottomLimit,
      },
    }

    console.log('config symbol start', market.symbol.code)
    await configFacet.connect(wallet).setSymbolConfig(symbolConfig)
    console.log('config symbol end', market.symbol.code)

    console.log('config market end', market.symbol.code)
  }

  console.log('create usdPool start', usdPool.name)
  const alreadyUsdPool = await poolFacet.getUsdPool()
  if (alreadyUsdPool.stableTokens.length > 0) {
    console.log('ignore with usdPool exists', usdPool.name)
  } else {
    await marketManagerFacet.connect(wallet).createStakeUsdPool(usdPool.name, usdPool.decimals)
    console.log('create usdPool end', usdPool.name)
  }

  const usdConfigParams = {
    config: {
      poolLiquidityLimit: usdPool.poolLiquidityLimit,
      mintFeeRate: usdPool.mintFeeRate,
      redeemFeeRate: usdPool.redeemFeeRate,
      unsettledRatioLimit: usdPool.unsettledRatioLimit,
      supportStableTokens: _.map(usdPool.supportStableTokens, function (token) {
        return tokens[token].address
      }),
      stableTokensBorrowingInterestRate: usdPool.stableTokensBorrowingInterestRate,
    },
  }
  console.log(usdConfigParams)
  await configFacet.connect(wallet).setUsdPoolConfig(usdConfigParams)

  console.log('config common start')
  const configParams = {
    chainConfig: {
      wrapperToken: tokens[commonConfig.chainConfig.wrapperToken].address,
      mintGasFeeLimit: commonConfig.chainConfig.mintGasFeeLimit,
      redeemGasFeeLimit: commonConfig.chainConfig.redeemGasFeeLimit,
      placeIncreaseOrderGasFeeLimit: commonConfig.chainConfig.placeIncreaseOrderGasFeeLimit,
      placeDecreaseOrderGasFeeLimit: commonConfig.chainConfig.placeDecreaseOrderGasFeeLimit,
      positionUpdateMarginGasFeeLimit: commonConfig.chainConfig.positionUpdateMarginGasFeeLimit,
      positionUpdateLeverageGasFeeLimit: commonConfig.chainConfig.positionUpdateLeverageGasFeeLimit,
      withdrawGasFeeLimit: commonConfig.chainConfig.withdrawGasFeeLimit,
      claimRewardsGasFeeLimit: commonConfig.chainConfig.claimRewardsGasFeeLimit,
    },
    tradeConfig: {
      tradeTokens: _.map(commonConfig.tradeConfig.tokens, function (token: string) {
        return tokens[token].address
      }),
      tradeTokenConfigs: _.map(commonConfig.tradeConfig.tokens, function (token: string) {
        const tokenConfigs = commonConfig.tradeConfig.tokenConfigs[token]
        tokenConfigs.priorityCollaterals = _.map(tokenConfigs.priorityCollaterals, function (priToken: string) {
          return tokens[priToken].address
        })
        return tokenConfigs
      }),
      minOrderMarginUSD: commonConfig.tradeConfig.minOrderMarginUSD,
      availableCollateralRatio: commonConfig.tradeConfig.availableCollateralRatio,
      crossLtvLimit: commonConfig.tradeConfig.crossLtvLimit,
      maxMaintenanceMarginRate: commonConfig.tradeConfig.maxMaintenanceMarginRate,
      fundingFeeBaseRate: commonConfig.tradeConfig.fundingFeeBaseRate,
      maxFundingBaseRate: commonConfig.tradeConfig.maxFundingBaseRate,
      tradingFeeStakingRewardsRatio: commonConfig.tradeConfig.tradingFeeStakingRewardsRatio,
      tradingFeePoolRewardsRatio: commonConfig.tradeConfig.tradingFeePoolRewardsRatio,
      tradingFeeUsdPoolRewardsRatio: commonConfig.tradeConfig.tradingFeeUsdPoolRewardsRatio,
      borrowingFeeStakingRewardsRatio: commonConfig.tradeConfig.borrowingFeeStakingRewardsRatio,
      borrowingFeePoolRewardsRatio: commonConfig.tradeConfig.borrowingFeePoolRewardsRatio,
      autoReduceProfitFactor: commonConfig.tradeConfig.autoReduceProfitFactor,
      autoReduceLiquidityFactor: commonConfig.tradeConfig.autoReduceLiquidityFactor,
      swapSlipperTokenFactor: commonConfig.tradeConfig.swapSlipperTokenFactor,
    },
    stakeConfig: {
      minPrecisionMultiple: commonConfig.stakeConfig.minPrecisionMultiple,
      collateralProtectFactor: commonConfig.stakeConfig.collateralProtectFactor,
      collateralFactor: commonConfig.stakeConfig.collateralFactor,
      mintFeeStakingRewardsRatio: commonConfig.stakeConfig.mintFeeStakingRewardsRatio,
      mintFeePoolRewardsRatio: commonConfig.stakeConfig.mintFeePoolRewardsRatio,
      redeemFeeStakingRewardsRatio: commonConfig.stakeConfig.redeemFeeStakingRewardsRatio,
      redeemFeePoolRewardsRatio: commonConfig.stakeConfig.redeemFeePoolRewardsRatio,
      poolRewardsIntervalLimit: commonConfig.stakeConfig.poolRewardsIntervalLimit,
      minApr: commonConfig.stakeConfig.minApr,
      maxApr: commonConfig.stakeConfig.maxApr,
    },
    uniswapRouter: commonConfig.commonConfig.uniswapRouter,
  }

  console.log(configParams)
  await configFacet.connect(wallet).setConfig(configParams)

  console.log('config common end')
}

func.tags = ['Configure']
func.dependencies = ['Tokens', 'Vaults', 'DiamondFacets']
export default func
