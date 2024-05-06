// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../storage/FeeRewards.sol";
import "../storage/Position.sol";
import "../storage/StakingAccount.sol";
import "./MarketProcess.sol";

library FeeProcess {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedMath for int256;
    using SignedSafeMath for int256;
    using SafeERC20 for IERC20;
    using Position for Position.Props;
    using UsdPool for UsdPool.Props;
    using LpPool for LpPool.Props;
    using StakingAccount for StakingAccount.Props;
    using FeeRewards for FeeRewards.MarketRewards;
    using FeeRewards for FeeRewards.StakingRewards;

    bytes32 public constant FEE_MINT = keccak256(abi.encode("FEE_MINT"));

    bytes32 public constant FEE_REDEEM = keccak256(abi.encode("FEE_REDEEM"));

    bytes32 public constant FEE_OPEN_POSITION = keccak256(abi.encode("FEE_OPEN_POSITION"));

    bytes32 public constant FEE_CLOSE_POSITION = keccak256(abi.encode("FEE_CLOSE_POSITION"));

    bytes32 public constant FEE_LIQUIDATION = keccak256(abi.encode("FEE_LIQUIDATION"));

    bytes32 public constant FEE_BORROWING = keccak256(abi.encode("FEE_BORROWING"));

    bytes32 public constant FEE_FUNDING = keccak256(abi.encode("FEE_FUNDING"));

    struct ChargeMintOrRedeemFeeEventParams {
        address stakeToken;
        address feeToken;
        address account;
        bytes32 feeType;
        uint256 fee;
    }

    struct ChargeFeeCache {
        uint256 ratioToStakingRewards;
        uint256 ratioToPoolRewards;
        uint256 feeToStakingRewards;
        uint256 feeToMarketRewards;
        uint256 feeToPoolRewards;
        uint256 feeToDaoRewards;
        address stakeToken;
    }

    event ChargeTradingFeeEvent(
        bytes32 symbol,
        address account,
        bytes32 positionKey,
        bytes32 feeType,
        address feeToken,
        uint256 feeAmount
    );

    event ChargeMintOrRedeemFeeEvent(ChargeMintOrRedeemFeeEventParams params);

    event ChargeBorrowingFeeEvent(
        bool isCrossMargin,
        address stakeToken,
        address token,
        address account,
        bytes32 feeType,
        uint256 fee
    );

    function updateBorrowingFee(Position.Props storage position, address stakeToken) public {
        uint256 cumulativeBorrowingFeePerToken = MarketQueryProcess.getCumulativeBorrowingFeePerToken(
            stakeToken,
            position.isLong,
            position.marginToken
        );
        uint256 realizedBorrowingFeeDelta = CalUtils.mulSmallRate(
            CalUtils.mulRate(position.initialMargin, position.leverage - CalUtils.RATE_PRECISION),
            cumulativeBorrowingFeePerToken - position.positionFee.openBorrowingFeePerToken
        );
        position.positionFee.realizedBorrowingFee += realizedBorrowingFeeDelta;
        position.positionFee.realizedBorrowingFeeInUsd += CalUtils.tokenToUsd(
            realizedBorrowingFeeDelta,
            TokenUtils.decimals(position.marginToken),
            OracleProcess.getLatestUsdUintPrice(position.marginToken, position.isLong)
        );
        position.positionFee.openBorrowingFeePerToken = cumulativeBorrowingFeePerToken;
        MarketProcess.updateTotalBorrowingFee(
            stakeToken,
            position.isLong,
            position.marginToken,
            0,
            realizedBorrowingFeeDelta.toInt256()
        );
    }

    function updateFundingFee(Position.Props storage position) public {
        int256 fundingFeePerQty = MarketQueryProcess.getFundingFeePerQty(position.symbol, position.isLong);
        if (fundingFeePerQty == position.positionFee.openFundingFeePerQty) {
            return;
        }
        int256 realizedFundingFeeDelta = CalUtils.mulIntSmallRate(
            position.qty.toInt256(),
            (fundingFeePerQty - position.positionFee.openFundingFeePerQty)
        );
        int256 realizedFundingFee;
        if (position.isLong) {
            realizedFundingFee = realizedFundingFeeDelta;
            position.positionFee.realizedFundingFee += realizedFundingFeeDelta;
            position.positionFee.realizedFundingFeeInUsd += CalUtils.tokenToUsdInt(
                realizedFundingFeeDelta,
                TokenUtils.decimals(position.marginToken),
                OracleProcess.getLatestUsdPrice(position.marginToken, position.isLong)
            );
        } else {
            realizedFundingFee = CalUtils.usdToTokenInt(
                realizedFundingFeeDelta,
                TokenUtils.decimals(position.marginToken),
                OracleProcess.getLatestUsdPrice(position.marginToken, position.isLong)
            );
            position.positionFee.realizedFundingFee += realizedFundingFee;
            position.positionFee.realizedFundingFeeInUsd += realizedFundingFeeDelta;
        }
        position.positionFee.openFundingFeePerQty = fundingFeePerQty;
        MarketProcess.updateMarketFundingFee(
            position.symbol,
            realizedFundingFee,
            position.isLong,
            true,
            position.marginToken
        );
    }

    function chargeTradingFee(
        uint256 fee,
        bytes32 symbol,
        bytes32 feeType,
        address feeToken,
        Position.Props memory position
    ) internal {
        FeeRewards.StakingRewards storage stakingRewardsProps = FeeRewards.loadStakingRewards();
        FeeRewards.MarketRewards storage marketTradingRewardsProps = FeeRewards.loadMarketTradingRewards(symbol);
        FeeRewards.StakingRewards storage daoRewardsProps = FeeRewards.loadDaoRewards();
        AppTradeConfig.TradeConfig memory tradeConfig = AppTradeConfig.getTradeConfig();
        ChargeFeeCache memory cache;
        cache.stakeToken = Symbol.load(symbol).stakeToken;
        cache.feeToStakingRewards = CalUtils.mulRate(fee, tradeConfig.tradingFeeStakingRewardsRatio);
        cache.feeToMarketRewards = CalUtils.mulRate(fee, tradeConfig.tradingFeePoolRewardsRatio);
        cache.feeToDaoRewards = fee.sub(cache.feeToStakingRewards).sub(cache.feeToMarketRewards);

        marketTradingRewardsProps.addFeeAmount(feeToken, cache.feeToMarketRewards);
        stakingRewardsProps.addFeeAmount(cache.stakeToken, feeToken, cache.feeToStakingRewards);
        daoRewardsProps.addFeeAmount(cache.stakeToken, feeToken, cache.feeToDaoRewards);
        if (position.isCrossMargin) {
            marketTradingRewardsProps.addUnsettleFeeAmount(feeToken, cache.feeToMarketRewards);
            stakingRewardsProps.addUnsettleFeeAmount(cache.stakeToken, feeToken, cache.feeToStakingRewards);
            daoRewardsProps.addUnsettleFeeAmount(cache.stakeToken, feeToken, cache.feeToDaoRewards);
        }
        emit ChargeTradingFeeEvent(symbol, position.account, position.key, feeType, feeToken, fee);
    }

    function chargeMintOrRedeemFee(
        uint256 fee,
        address stakeToken,
        address feeToken,
        address account,
        bytes32 feeType,
        bool isCollateral
    ) public {
        ChargeFeeCache memory cache;
        AppPoolConfig.StakeConfig memory stakeConfig = AppPoolConfig.getStakeConfig();
        if (feeType == FEE_MINT) {
            cache.ratioToStakingRewards = stakeConfig.mintFeeStakingRewardsRatio;
            cache.ratioToPoolRewards = stakeConfig.mintFeePoolRewardsRatio;
        } else if (feeType == FEE_REDEEM) {
            cache.ratioToStakingRewards = stakeConfig.redeemFeeStakingRewardsRatio;
            cache.ratioToPoolRewards = stakeConfig.redeemFeePoolRewardsRatio;
        }
        cache.feeToStakingRewards = CalUtils.mulRate(fee, cache.ratioToStakingRewards);
        cache.feeToPoolRewards = CalUtils.mulRate(fee, cache.ratioToPoolRewards);
        cache.feeToDaoRewards = fee.sub(cache.feeToStakingRewards).sub(cache.feeToPoolRewards);
        FeeRewards.StakingRewards storage stakingRewardsProps = FeeRewards.loadStakingRewards();
        FeeRewards.MarketRewards storage poolRewardsProps = FeeRewards.loadPoolRewards(stakeToken);
        FeeRewards.StakingRewards storage daoRewardsProps = FeeRewards.loadDaoRewards();
        if (isCollateral) {
            stakingRewardsProps.addCollateralFeeAmount(stakeToken, feeToken, cache.feeToStakingRewards);
            poolRewardsProps.addCollateralFeeAmount(feeToken, cache.feeToPoolRewards);
            daoRewardsProps.addCollateralFeeAmount(stakeToken, feeToken, cache.feeToDaoRewards);
        } else {
            stakingRewardsProps.addFeeAmount(stakeToken, feeToken, cache.feeToStakingRewards);
            poolRewardsProps.addFeeAmount(feeToken, cache.feeToPoolRewards);
            daoRewardsProps.addFeeAmount(stakeToken, feeToken, cache.feeToDaoRewards);
        }

        ChargeMintOrRedeemFeeEventParams memory params = ChargeMintOrRedeemFeeEventParams({
            stakeToken: stakeToken,
            feeToken: feeToken,
            account: account,
            feeType: feeType,
            fee: fee
        });

        emit ChargeMintOrRedeemFeeEvent(params);
    }

    function chargeBorrowingFee(
        bool isCrossMargin,
        uint256 fee,
        address stakeToken,
        address feeToken,
        address account,
        bytes32 feeType
    ) public {
        FeeRewards.StakingRewards storage stakingRewardsProps = FeeRewards.loadStakingRewards();
        FeeRewards.MarketRewards storage poolRewardsProps = FeeRewards.loadPoolRewards(stakeToken);
        FeeRewards.StakingRewards storage daoRewardsProps = FeeRewards.loadDaoRewards();

        AppTradeConfig.TradeConfig memory tradeConfig = AppTradeConfig.getTradeConfig();
        ChargeFeeCache memory cache;
        cache.feeToStakingRewards = CalUtils.mulRate(fee, tradeConfig.borrowingFeeStakingRewardsRatio);
        cache.feeToPoolRewards = CalUtils.mulRate(fee, tradeConfig.borrowingFeePoolRewardsRatio);
        cache.feeToDaoRewards = fee.sub(cache.feeToStakingRewards).sub(cache.feeToPoolRewards);

        stakingRewardsProps.addFeeAmount(stakeToken, feeToken, cache.feeToStakingRewards);
        poolRewardsProps.addFeeAmount(feeToken, cache.feeToPoolRewards);
        daoRewardsProps.addFeeAmount(stakeToken, feeToken, cache.feeToDaoRewards);

        if (isCrossMargin) {
            stakingRewardsProps.addUnsettleFeeAmount(stakeToken, feeToken, cache.feeToStakingRewards);
            poolRewardsProps.addUnsettleFeeAmount(feeToken, cache.feeToPoolRewards);
            daoRewardsProps.addUnsettleFeeAmount(stakeToken, feeToken, cache.feeToDaoRewards);
        }

        emit ChargeBorrowingFeeEvent(isCrossMargin, stakeToken, feeToken, account, feeType, fee);
    }
}
