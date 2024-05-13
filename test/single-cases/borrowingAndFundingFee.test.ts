import { expect } from "chai";
import { Fixture, deployFixture } from "@test/deployFixture";
import {
  ORDER_ID_KEY,
  OrderSide,
  OrderType,
  PositionSide,
  StopType,
} from "@utils/constants";
import { precision } from "@utils/precision";
import {
  AccountFacet,
  FeeFacet,
  MarketFacet,
  MockToken,
  OrderFacet,
  PoolFacet,
  PositionFacet,
  TradeVault,
  ConfigFacet,
} from "types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { handleOrder } from "@utils/order";
import { handleMint } from "@utils/mint";
import { time } from "@nomicfoundation/hardhat-network-helpers";
import { pool } from "@utils/pool";
import { configUtils } from "@utils/config";
import { IConfig } from "types/contracts/facets/ConfigFacet";
import { oracles } from "@utils/oracles";

describe("Borrowing And Funding Fee Process", function () {
  let fixture: Fixture;
  let tradeVault: TradeVault,
    marketFacet: MarketFacet,
    orderFacet: OrderFacet,
    poolFacet: PoolFacet,
    accountFacet: AccountFacet,
    positionFacet: PositionFacet,
    feeFacet: FeeFacet,
    configFacet: ConfigFacet;
  let user0: HardhatEthersSigner,
    user1: HardhatEthersSigner,
    user2: HardhatEthersSigner,
    user3: HardhatEthersSigner;
  let diamondAddr: string,
    tradeVaultAddr: string,
    wbtcAddr: string,
    wethAddr: string,
    usdcAddr: string;
  let btcUsd: string, ethUsd: string, xBtc: string, xEth: string, xUsd: string;
  let wbtc: MockToken, weth: MockToken, usdc: MockToken;
  let config: IConfig.CommonConfigParamsStructOutput;

  beforeEach(async () => {
    fixture = await deployFixture();
    ({
      tradeVault,
      marketFacet,
      poolFacet,
      orderFacet,
      accountFacet,
      positionFacet,
      feeFacet,
      configFacet,
    } = fixture.contracts);
    ({ user0, user1, user2, user3 } = fixture.accounts);
    ({ btcUsd, ethUsd } = fixture.symbols);
    ({ xBtc, xEth, xUsd } = fixture.pools);
    ({ wbtc, weth, usdc } = fixture.tokens);
    ({ diamondAddr, tradeVaultAddr } = fixture.addresses);
    wbtcAddr = await wbtc.getAddress();
    wethAddr = await weth.getAddress();
    usdcAddr = await usdc.getAddress();

    config = await configFacet.getConfig();

    const btcTokenPrice = precision.price(25000);
    const btcOracle = [
      { token: wbtcAddr, minPrice: btcTokenPrice, maxPrice: btcTokenPrice },
    ];
    await handleMint(fixture, {
      stakeToken: xBtc,
      requestToken: wbtc,
      requestTokenAmount: precision.token(100),
      oracle: btcOracle,
    });

    const ethTokenPrice = precision.price(1600);
    const ethOracle = [
      { token: wethAddr, minPrice: ethTokenPrice, maxPrice: ethTokenPrice },
    ];
    await handleMint(fixture, {
      requestTokenAmount: precision.token(1000),
      oracle: ethOracle,
    });

    const usdtTokenPrice = precision.price(1);
    const usdcTokenPrice = precision.price(101, 6);
    const daiTokenPrice = precision.price(99, 7);
    const usdOracle = [
      { token: usdcAddr, minPrice: usdcTokenPrice, maxPrice: usdcTokenPrice },
    ];

    await handleMint(fixture, {
      requestTokenAmount: precision.token(100000, 6),
      stakeToken: xUsd,
      requestToken: usdc,
      oracle: usdOracle,
    });
  });

  it("Case1: ethUsd borrowing fee test", async function () {
    const tokenBalance0 = BigInt(await weth.balanceOf(user0.address));
    const vaultBalance0 = BigInt(await weth.balanceOf(tradeVaultAddr));
    const marketBalance0 = BigInt(await weth.balanceOf(xEth));
    const symbolInfo = await marketFacet.getSymbol(ethUsd);

    const orderMargin1 = precision.token(1, 17); // 0.1ETH
    const ethPrice1 = precision.price(1800);
    const ethOracle1 = [
      { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
    ];
    const executionFee = precision.token(2, 15);

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      oracle: ethOracle1,
      executionFee: executionFee,
    });

    const time1 = await time.latest();
    const tokenBalance1 = BigInt(await weth.balanceOf(user0.address));
    const vaultBalance1 = BigInt(await weth.balanceOf(tradeVaultAddr));
    const marketBalance1 = BigInt(await weth.balanceOf(xEth));
    const leverageMargin1 = precision.mulRate(orderMargin1, precision.rate(10));
    const tradeFee1 = precision.mulRate(
      leverageMargin1,
      symbolInfo.config.openFeeRate
    );
    const initialMargin1 = orderMargin1 - tradeFee1;

    // vault & user token amount
    expect(0).to.equals(vaultBalance1 - vaultBalance0);
    expect(orderMargin1).to.equals(marketBalance1 - marketBalance0);
    expect(orderMargin1).to.equals(tokenBalance0 - tokenBalance1);

    // Account
    const accountInfo1 = await accountFacet.getAccountInfo(user0.address);
    expect(user0.address).to.equals(accountInfo1.owner);

    // pool
    const poolInfo1 = await poolFacet.getPool(xEth);
    expect(initialMargin1 * BigInt(10 - 1)).to.equals(
      poolInfo1.baseTokenBalance.holdAmount
    );
    expect(time1).to.equals(poolInfo1.borrowingFee.lastUpdateTime);

    // config
    const poolConfig = await configFacet.getPoolConfig(xEth);

    // Position
    const defaultMarginMode = false;
    const positionInfo1 = await positionFacet.getSinglePosition(
      user0.address,
      ethUsd,
      wethAddr,
      defaultMarginMode
    );
    expect(initialMargin1).to.equals(positionInfo1.initialMargin);
    expect(initialMargin1 * BigInt(1800)).to.equals(
      positionInfo1.initialMarginInUsd
    );
    expect(initialMargin1 * BigInt(1800)).to.equals(
      positionInfo1.initialMarginInUsdFromBalance
    );
    expect(precision.rate(10)).to.equals(positionInfo1.leverage);
    expect(ethPrice1).to.equals(positionInfo1.entryPrice);
    expect(ethUsd).to.equals(positionInfo1.symbol);
    expect(wethAddr).to.equals(positionInfo1.marginToken);
    expect(symbolInfo.indexToken).to.equals(positionInfo1.indexToken);
    expect(true).to.equals(positionInfo1.isLong);
    expect(initialMargin1 * BigInt(10) * BigInt(1800)).to.equals(
      positionInfo1.qty
    );
    expect(initialMargin1 * BigInt(10 - 1)).to.equals(
      positionInfo1.holdPoolAmount
    );
    expect(-tradeFee1 * BigInt(1800)).to.equals(positionInfo1.realizedPnl);

    // Market
    const marketInfo1 = await marketFacet.getMarketInfo(
      ethUsd,
      oracles.format(ethOracle1)
    );
    expect(initialMargin1 * BigInt(10) * BigInt(1800)).to.equals(
      marketInfo1.longPositionInterest
    );

    const orderMargin2 = precision.token(12, 17); // 1.2ETH

    time.increase(100);

    await handleOrder(fixture, {
      orderMargin: orderMargin2,
      oracle: ethOracle1,
      executionFee: executionFee,
    });

    const time2 = await time.latest();
    const tokenBalance2 = BigInt(await weth.balanceOf(user0.address));
    const vaultBalance2 = BigInt(await weth.balanceOf(tradeVaultAddr));
    const marketBalance2 = BigInt(await weth.balanceOf(xEth));

    // compute trading fee
    const leverageMargin2 = precision.mulRate(orderMargin2, precision.rate(10));
    const tradeFee2 = precision.mulRate(
      leverageMargin2,
      symbolInfo.config.openFeeRate
    );
    const initialMargin2 = orderMargin2 - tradeFee2;

    // compute borrowing fee
    const borrowingPerTokenDelta =
      BigInt(time2 - time1) *
      ((poolConfig.baseInterestRate * poolInfo1.baseTokenBalance.holdAmount) /
        poolInfo1.baseTokenBalance.amount);

    const realizedBorrowingFee =
      (borrowingPerTokenDelta *
        precision.mulRate(initialMargin1, precision.rate(10 - 1))) /
      BigInt(10 ** 18);
    const realizedBorrowingFeeInUsd = precision.mulPrice(
      realizedBorrowingFee,
      ethPrice1
    );

    // vault & user token amount
    expect(0).to.equals(vaultBalance2 - vaultBalance1);
    expect(orderMargin2).to.equals(marketBalance2 - marketBalance1);
    expect(orderMargin2).to.equals(tokenBalance1 - tokenBalance2);

    // pool
    const poolInfo2 = await poolFacet.getPool(xEth);
    expect((initialMargin1 + initialMargin2) * BigInt(10 - 1)).to.equals(
      poolInfo2.baseTokenBalance.holdAmount
    );
    expect(time2).to.equals(poolInfo2.borrowingFee.lastUpdateTime);
    expect(borrowingPerTokenDelta).to.equals(
      poolInfo2.borrowingFee.cumulativeBorrowingFeePerToken
    );
    expect(0).to.equals(poolInfo2.borrowingFee.totalBorrowingFee);
    expect(realizedBorrowingFee).to.equals(
      poolInfo2.borrowingFee.totalRealizedBorrowingFee
    );

    // Position
    const positionInfo2 = await positionFacet.getSinglePosition(
      user0.address,
      ethUsd,
      wethAddr,
      defaultMarginMode
    );
    expect(initialMargin1 + initialMargin2).to.equals(
      positionInfo2.initialMargin
    );
    expect((initialMargin1 + initialMargin2) * BigInt(1800)).to.equals(
      positionInfo2.initialMarginInUsd
    );
    expect((initialMargin1 + initialMargin2) * BigInt(1800)).to.equals(
      positionInfo2.initialMarginInUsdFromBalance
    );
    expect(
      (initialMargin1 + initialMargin2) * BigInt(10) * BigInt(1800)
    ).to.equals(positionInfo2.qty);
    expect((initialMargin1 + initialMargin2) * BigInt(10 - 1)).to.equals(
      positionInfo2.holdPoolAmount
    );
    expect((-tradeFee1 - tradeFee2) * BigInt(1800)).to.equals(
      positionInfo2.realizedPnl
    );
    expect(borrowingPerTokenDelta).to.equals(
      positionInfo2.positionFee.openBorrowingFeePerToken
    );
    expect(realizedBorrowingFee).to.equals(
      positionInfo2.positionFee.realizedBorrowingFee
    );
    expect(realizedBorrowingFeeInUsd).to.equals(
      positionInfo2.positionFee.realizedBorrowingFeeInUsd
    );

    // Market
    const marketInfo = await marketFacet.getMarketInfo(
      ethUsd,
      oracles.format(ethOracle1)
    );
    expect(
      (initialMargin1 + initialMargin2) * BigInt(10) * BigInt(1800)
    ).to.equals(marketInfo.longPositionInterest);

    const orderMargin3 = precision.token(3, 17); // 0.3ETH
    await handleOrder(fixture, {
      orderMargin: orderMargin3,
      oracle: ethOracle1,
      executionFee: executionFee,
    });
  });

  it("Case2: ethUsd borrowing & funding fee test", async function () {
    const symbolInfo = await marketFacet.getSymbol(ethUsd);

    const orderMargin1 = precision.token(1, 17); // 0.1ETH
    const ethPrice1 = precision.price(1800);
    const oracle1 = [
      { token: wethAddr, minPrice: ethPrice1, maxPrice: ethPrice1 },
    ];
    const executionFee = precision.token(2, 15);

    await handleOrder(fixture, {
      orderMargin: orderMargin1,
      oracle: oracle1,
      executionFee: executionFee,
    });

    const time1 = await time.latest();
    const leverageMargin1 = precision.mulRate(orderMargin1, precision.rate(10));
    const tradeFee1 = precision.mulRate(
      leverageMargin1,
      symbolInfo.config.openFeeRate
    );
    const initialMargin1 = orderMargin1 - tradeFee1;

    // pool
    const poolInfo1 = await poolFacet.getPool(xEth);
    expect(time1).to.equals(poolInfo1.borrowingFee.lastUpdateTime);

    // Position
    const defaultMarginMode = false;
    const user0PositionInfo1 = await positionFacet.getSinglePosition(
      user0.address,
      ethUsd,
      wethAddr,
      defaultMarginMode
    );
    expect(0).to.equals(
      user0PositionInfo1.positionFee.openBorrowingFeePerToken
    );
    expect(0).to.equals(user0PositionInfo1.positionFee.openFundingFeePerQty);

    // Market
    const marketInfo1 = await marketFacet.getMarketInfo(
      ethUsd,
      oracles.format(oracle1)
    );
    expect(time1).to.equals(marketInfo1.fundingFee.lastUpdateTime);

    time.increase(99);

    const ethPrice2 = ethPrice1 + precision.price(50);
    const usdcPrice2 = precision.price(1);
    const oracle2 = [
      { token: wethAddr, minPrice: ethPrice2, maxPrice: ethPrice2 },
      { token: usdcAddr, minPrice: usdcPrice2, maxPrice: usdcPrice2 },
    ];
    const orderMargin2 = precision.token(999, 6); // 999USDC
    await handleOrder(fixture, {
      orderMargin: orderMargin2,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      oracle: oracle2,
    });
    const time2 = await time.latest();
    const leverageMargin2 = precision.mulRate(orderMargin2, precision.rate(10));
    const tradeFee2 = precision.mulRate(
      leverageMargin2,
      symbolInfo.config.openFeeRate
    );
    const initialMargin2 = orderMargin2 - tradeFee2;

    // pool
    const usdPoolInfo2 = await poolFacet.getUsdPool();
    expect(time2).to.equals(
      pool.getUsdPoolBorrowingFee(usdPoolInfo2, usdcAddr)?.lastUpdateTime
    );

    // Position
    const user0PositionInfo2 = await positionFacet.getSinglePosition(
      user0.address,
      ethUsd,
      usdcAddr,
      defaultMarginMode
    );
    expect(0).to.equals(
      user0PositionInfo2.positionFee.openBorrowingFeePerToken
    );
    expect(0).to.equals(user0PositionInfo2.positionFee.openFundingFeePerQty);

    // Market
    const marketInfo2 = await marketFacet.getMarketInfo(
      ethUsd,
      oracles.format(oracle2)
    );
    expect(time2).to.equals(marketInfo2.fundingFee.lastUpdateTime);

    // Funding Fee
    const poolInfo2 = await poolFacet.getPool(xEth);
    const ethFundingRatePerSecond0 =
      (config.tradeConfig.fundingFeeBaseRate * user0PositionInfo1.qty) /
      user0PositionInfo1.qty;
    const fundingFeeInUsd0 =
      user0PositionInfo1.qty * ethFundingRatePerSecond0 * BigInt(time2 - time1);
    const longFundingFeePerQtyDelta0 = precision.divPrice(
      fundingFeeInUsd0 / user0PositionInfo1.qty,
      ethPrice2
    );
    const shortFundingFeePerQtyDelta0 =
      -fundingFeeInUsd0 / user0PositionInfo1.qty;

    // config
    const poolConfig = await configFacet.getPoolConfig(xEth);

    time.increase(199);

    const ethPrice3 = ethPrice2 - precision.price(20);
    const usdcPrice3 = precision.price(1);
    const oracle3 = [
      { token: wethAddr, minPrice: ethPrice3, maxPrice: ethPrice3 },
      { token: usdcAddr, minPrice: usdcPrice3, maxPrice: usdcPrice3 },
    ];
    const orderMargin3 = precision.token(1, 17); // 0.1ETH
    await handleOrder(fixture, {
      orderMargin: orderMargin3,
      oracle: oracle3,
      executionFee: executionFee,
    });

    const time3 = await time.latest();

    const ethBorrowingPerTokenDelta =
      BigInt(time3 - time1) *
      ((poolConfig.baseInterestRate * poolInfo1.baseTokenBalance.holdAmount) /
        poolInfo1.baseTokenBalance.amount);

    const realizedEthBorrowingFee =
      (ethBorrowingPerTokenDelta *
        precision.mulRate(initialMargin1, precision.rate(10 - 1))) /
      BigInt(10 ** 18);
    const realizedEthBorrowingFeeInUsd = precision.mulPrice(
      realizedEthBorrowingFee,
      ethPrice3
    );

    // ethFundingRatePerSecond < 0
    const ethFundingRatePerSecond =
      (config.tradeConfig.fundingFeeBaseRate *
        (user0PositionInfo1.qty - user0PositionInfo2.qty)) /
      (user0PositionInfo2.qty + user0PositionInfo1.qty);
    const fundingFeeInUsd =
      user0PositionInfo2.qty * ethFundingRatePerSecond * BigInt(time3 - time2);
    const longFundingFeePerQtyDelta = precision.divPrice(
      fundingFeeInUsd / user0PositionInfo1.qty,
      ethPrice3
    );
    const shortFundingFeePerQtyDelta = -fundingFeeInUsd / user0PositionInfo2.qty;
    const realizedEthFundingFeeDelta =
      (user0PositionInfo1.qty *
        (longFundingFeePerQtyDelta0 + longFundingFeePerQtyDelta)) /
      BigInt(10 ** 18);

    // pool
    const poolInfo3 = await poolFacet.getPool(xEth);
    expect(time3).to.equals(poolInfo3.borrowingFee.lastUpdateTime);
    expect(ethBorrowingPerTokenDelta).to.equals(
      poolInfo3.borrowingFee.cumulativeBorrowingFeePerToken
    );
    expect(realizedEthBorrowingFee).to.equals(
      poolInfo3.borrowingFee.totalRealizedBorrowingFee
    );
    expect(0).to.equals(poolInfo3.borrowingFee.totalBorrowingFee);
    expect(realizedEthFundingFeeDelta).to.equals(
      poolInfo3.baseTokenBalance.unsettledAmount
    );

    const usdPoolInfo3 = await poolFacet.getUsdPool();
    expect(time2).to.equals(
      pool.getUsdPoolBorrowingFee(usdPoolInfo3, usdcAddr)?.lastUpdateTime
    );

    // Position
    const user0PositionInfo3 = await positionFacet.getSinglePosition(
      user0.address,
      ethUsd,
      wethAddr,
      defaultMarginMode
    );
    expect(ethBorrowingPerTokenDelta).to.equals(
      user0PositionInfo3.positionFee.openBorrowingFeePerToken
    );
    expect(realizedEthBorrowingFee).to.equals(
      user0PositionInfo3.positionFee.realizedBorrowingFee
    );
    expect(realizedEthBorrowingFeeInUsd).to.equals(
      user0PositionInfo3.positionFee.realizedBorrowingFeeInUsd
    );
    expect(longFundingFeePerQtyDelta0 + longFundingFeePerQtyDelta).to.equals(
      user0PositionInfo3.positionFee.openFundingFeePerQty
    );

    const user1PositionInfo3 = await positionFacet.getSinglePosition(
      user0.address,
      ethUsd,
      usdcAddr,
      defaultMarginMode
    );
    expect(0).to.equals(
      user1PositionInfo3.positionFee.openBorrowingFeePerToken
    );
    expect(0).to.equals(user1PositionInfo3.positionFee.openFundingFeePerQty);

    // Market
    const marketInfo3 = await marketFacet.getMarketInfo(
      ethUsd,
      oracles.format(oracle3)
    );
    expect(time3).to.equals(marketInfo3.fundingFee.lastUpdateTime);
    expect(longFundingFeePerQtyDelta0 + longFundingFeePerQtyDelta).to.equals(
      marketInfo3.fundingFee.longFundingFeePerQty
    );
    expect(shortFundingFeePerQtyDelta).to.equals(
      marketInfo3.fundingFee.shortFundingFeePerQty
    );
    expect(realizedEthFundingFeeDelta).to.equals(
      marketInfo3.fundingFee.totalLongFundingFee
    );
    expect(0).to.equals(marketInfo3.fundingFee.totalShortFundingFee);

    const ethPrice4 = precision.price(1890);
    const usdcPrice4 = precision.price(1);
    const oracle4 = [
      { token: wethAddr, minPrice: ethPrice4, maxPrice: ethPrice4 },
      { token: usdcAddr, minPrice: usdcPrice4, maxPrice: usdcPrice4 },
    ];
    const orderMargin4 = precision.token(222, 6); // 222USDC
    await handleOrder(fixture, {
      orderMargin: orderMargin4,
      marginToken: usdc,
      orderSide: OrderSide.SHORT,
      oracle: oracle4,
    });
    const time4 = await time.latest();

    // config
    const usdPoolConfig = await configFacet.getUsdPoolConfig();

    const usdcBorrowingPerTokenDelta =
      BigInt(time4 - time2) *
      ((configUtils.getUsdPoolBorrowingBaseInterest(usdPoolConfig, usdcAddr) *
        pool.getUsdPoolStableTokenHoldAmount(usdPoolInfo2, usdcAddr)) /
        pool.getUsdPoolStableTokenAmount(usdPoolInfo2, usdcAddr));

    const realizedUsdcBorrowingFee =
      (usdcBorrowingPerTokenDelta *
        precision.mulRate(initialMargin2, precision.rate(10 - 1))) /
      BigInt(10 ** 18);
    const realizedUsdcBorrowingFeeInUsd = realizedUsdcBorrowingFee;

    // usdcFundingRatePerSecond < 0
    const usdcFundingRatePerSecond =
      (config.tradeConfig.fundingFeeBaseRate *
        (user0PositionInfo3.qty - user0PositionInfo2.qty)) /
      (user0PositionInfo2.qty + user0PositionInfo3.qty);
    const fundingFeeInUsd4 =
      user0PositionInfo2.qty * usdcFundingRatePerSecond * BigInt(time4 - time3);
    const longFundingFeePerQtyDelta4 =
      longFundingFeePerQtyDelta +
      precision.divPrice(-fundingFeeInUsd4 / user0PositionInfo3.qty, ethPrice4);
    const shortFundingFeePerQtyDelta4 =
      shortFundingFeePerQtyDelta + fundingFeeInUsd4 / user0PositionInfo2.qty;
    const realizedUsdcFundingFeeDelta =
      (user0PositionInfo2.qty * shortFundingFeePerQtyDelta4) / BigInt(10 ** 18);

    // pool
    const poolInfo4 = await poolFacet.getPool(xEth);
    expect(time3).to.equals(poolInfo4.borrowingFee.lastUpdateTime);
    expect(ethBorrowingPerTokenDelta).to.equals(
      poolInfo4.borrowingFee.cumulativeBorrowingFeePerToken
    );
    expect(realizedEthBorrowingFee).to.equals(
      poolInfo4.borrowingFee.totalRealizedBorrowingFee
    );
    expect(0).to.equals(poolInfo4.borrowingFee.totalBorrowingFee);
    expect(realizedEthFundingFeeDelta).to.equals(
      poolInfo4.baseTokenBalance.unsettledAmount
    );

    // expect(realizedUsdcFundingFeeDelta).to.equals(
    //   pool.getPoolStableTokenUnsettledAmount(poolInfo4, usdcAddr)
    // );

    const usdPoolInfo4 = await poolFacet.getUsdPool();
    expect(time4).to.equals(
      pool.getUsdPoolBorrowingFee(usdPoolInfo4, usdcAddr)?.lastUpdateTime
    );

    // Position
    const user0PositionInfo4 = await positionFacet.getSinglePosition(
      user0.address,
      ethUsd,
      wethAddr,
      defaultMarginMode
    );
    expect(ethBorrowingPerTokenDelta).to.equals(
      user0PositionInfo4.positionFee.openBorrowingFeePerToken
    );
    expect(realizedEthBorrowingFee).to.equals(
      user0PositionInfo4.positionFee.realizedBorrowingFee
    );
    expect(realizedEthBorrowingFeeInUsd).to.equals(
      user0PositionInfo4.positionFee.realizedBorrowingFeeInUsd
    );
    expect(longFundingFeePerQtyDelta0 + longFundingFeePerQtyDelta).to.equals(
      user0PositionInfo4.positionFee.openFundingFeePerQty
    );

    const user1PositionInfo4 = await positionFacet.getSinglePosition(
      user0.address,
      ethUsd,
      usdcAddr,
      defaultMarginMode
    );
    expect(usdcBorrowingPerTokenDelta).to.equals(
      user1PositionInfo4.positionFee.openBorrowingFeePerToken
    );
    // expect(shortFundingFeePerQtyDelta4).to.equals(
    //   user1PositionInfo4.positionFee.openFundingFeePerQty
    // );

    // Market
    const marketInfo4 = await marketFacet.getMarketInfo(
      ethUsd,
      oracles.format(oracle4)
    );
    expect(time4).to.equals(marketInfo4.fundingFee.lastUpdateTime);
    // expect(longFundingFeePerQtyDelta4).to.equals(
    //   marketInfo4.fundingFee.longFundingFeePerQty
    // );
    // expect(shortFundingFeePerQtyDelta4).to.equals(
    //   marketInfo4.fundingFee.shortFundingFeePerQty
    // );
    // expect(realizedEthFundingFeeDelta).to.equals(
    //   marketInfo4.fundingFee.totalLongFundingFee
    // );
    // expect(realizedUsdcFundingFeeDelta).to.equals(
    //   marketInfo4.fundingFee.totalShortFundingFee
    // );
  });
});
