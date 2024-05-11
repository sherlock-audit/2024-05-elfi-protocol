// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IFee.sol";
import "../storage/CommonData.sol";
import "../storage/ClaimRewards.sol";
import "../storage/UuidCreator.sol";
import "./VaultProcess.sol";
import "./LpPoolQueryProcess.sol";
import "./GasProcess.sol";
import "./AssetsProcess.sol";
import "./FeeRewardsProcess.sol";

library ClaimRewardsProcess {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using UsdPool for UsdPool.Props;
    using LpPool for LpPool.Props;
    using LpPoolQueryProcess for LpPool.Props;
    using LpPoolQueryProcess for UsdPool.Props;
    using StakingAccount for StakingAccount.Props;
    using FeeRewards for FeeRewards.MarketRewards;
    using FeeRewards for FeeRewards.StakingRewards;

    bytes32 constant CLAIM_ID_KEY = keccak256("CLAIM_ID_KEY");

    event CreateClaimRewardsEvent(uint256 indexed requestId, ClaimRewards.Request data);
    event ClaimRewardsSuccessEvent(
        uint256 indexed requestId,
        ClaimRewards.Request data,
        address[] stakeTokens,
        uint256[] claimAmounts
    );
    event CancelClaimRewardsEvent(uint256 indexed requestId, ClaimRewards.Request data, bytes32 reasonCode);

    function createClaimRewards(address account, address claimUsdToken, uint256 executionFee) external {
        if (!UsdPool.isSupportStableToken(claimUsdToken)) {
            revert Errors.ClaimTokenNotSupported();
        }
        AppConfig.ChainConfig memory chainConfig = AppConfig.getChainConfig();
        GasProcess.validateExecutionFeeLimit(executionFee, chainConfig.claimRewardsGasFeeLimit);
        require(msg.value == executionFee, "claim rewards with execution fee error!");
        AssetsProcess.depositToVault(
            AssetsProcess.DepositParams(
                account,
                chainConfig.wrapperToken,
                executionFee,
                AssetsProcess.DepositFrom.MANUAL,
                true
            )
        );
        uint256 requestId = UuidCreator.nextId(CLAIM_ID_KEY);
        ClaimRewards.Request storage request = ClaimRewards.create(requestId);
        request.account = account;
        request.claimUsdToken = claimUsdToken;
        request.executionFee = executionFee;
        emit CreateClaimRewardsEvent(requestId, request);
    }

    function claimRewards(uint256 requestId, ClaimRewards.Request memory request) external {
        address account = request.account;
        address[] memory stakeTokens = CommonData.getAllStakeTokens();
        StakingAccount.Props storage stakingAccount = StakingAccount.load(account);
        StakingAccount.FeeRewards storage accountFeeRewards;
        address[] memory allStakeTokens = new address[](stakeTokens.length + 1);
        uint256[] memory claimStakeTokenRewards = new uint256[](stakeTokens.length + 1);
        for (uint256 i; i < stakeTokens.length; i++) {
            address stakeToken = stakeTokens[i];
            allStakeTokens[i] = stakeToken;
            FeeRewards.MarketRewards storage feeProps = FeeRewards.loadPoolRewards(stakeToken);
            FeeRewardsProcess.updateAccountFeeRewards(account, stakeToken);
            accountFeeRewards = stakingAccount.getFeeRewards(stakeToken);
            if (accountFeeRewards.realisedRewardsTokenAmount == 0) {
                continue;
            }
            LpPool.Props storage pool = LpPool.load(stakeToken);
            uint256 withdrawPoolAmount = accountFeeRewards.realisedRewardsTokenAmount;
            claimStakeTokenRewards[i] = withdrawPoolAmount;
            pool.subBaseToken(withdrawPoolAmount);
            pool.totalClaimedRewards += withdrawPoolAmount;
            VaultProcess.transferOut(stakeToken, pool.baseToken, account, withdrawPoolAmount);
            accountFeeRewards.realisedRewardsTokenAmount = 0;
            accountFeeRewards.openRewardsPerStakeToken = feeProps.getCumulativeRewardsPerStakeToken();
            stakingAccount.emitFeeRewardsUpdateEvent(stakeToken);
        }

        FeeRewardsProcess.updateAccountFeeRewards(account, CommonData.getStakeUsdToken());

        accountFeeRewards = stakingAccount.getFeeRewards(CommonData.getStakeUsdToken());

        uint256 withdrawAmount = CalUtils.usdToToken(
            accountFeeRewards.realisedRewardsTokenAmount,
            TokenUtils.decimals(request.claimUsdToken),
            OracleProcess.getLatestUsdUintPrice(request.claimUsdToken, false)
        );

        allStakeTokens[allStakeTokens.length - 1] = CommonData.getStakeUsdToken();
        claimStakeTokenRewards[claimStakeTokenRewards.length - 1] = withdrawAmount;
        UsdPool.Props storage usdPool = UsdPool.load();
        usdPool.subStableToken(request.claimUsdToken, withdrawAmount);
        usdPool.totalClaimedRewards += accountFeeRewards.realisedRewardsTokenAmount;
        VaultProcess.transferOut(CommonData.getStakeUsdToken(), request.claimUsdToken, account, withdrawAmount);
        accountFeeRewards.realisedRewardsTokenAmount = 0;

        ClaimRewards.remove(requestId);
        emit ClaimRewardsSuccessEvent(requestId, request, allStakeTokens, claimStakeTokenRewards);
    }

    function cancelClaimRewards(uint256 requestId, ClaimRewards.Request memory request, bytes32 reasonCode) external {
        ClaimRewards.remove(requestId);
        emit CancelClaimRewardsEvent(requestId, request, reasonCode);
    }
}
