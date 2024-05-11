// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/IStake.sol";
import "../interfaces/IVault.sol";
import "../vault/Vault.sol";
import "../vault/LpVault.sol";
import "../vault/StakeToken.sol";
import "./LpPoolQueryProcess.sol";
import "./FeeProcess.sol";
import "./FeeRewardsProcess.sol";
import "./AssetsProcess.sol";
import "./FeeQueryProcess.sol";

library MintProcess {
    using LpPool for LpPool.Props;
    using LpPoolQueryProcess for LpPool.Props;
    using UsdPool for UsdPool.Props;
    using LpPoolQueryProcess for UsdPool.Props;
    using StakingAccount for StakingAccount.Props;
    using Account for Account.Props;
    using AccountProcess for Account.Props;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;

    bytes32 constant MINT_ID_KEY = keccak256("MINT_ID_KEY");

    struct ExecuteMintCache {
        address mintToken;
        uint256 mintFee;
        uint8 mintTokenDecimals;
        uint256 mintTokenAmount;
        uint256 mintStakeAmount;
    }

    event CancelMintEvent(uint256 indexed requestId, Mint.Request data, bytes32 reasonCode);
    event MintSuccessEvent(uint256 indexed requestId, uint256 mintStakeAmount, Mint.Request data);
    event CreateMintEvent(uint256 indexed requestId, Mint.Request data);

    function createMintStakeTokenRequest(
        IStake.MintStakeTokenParams memory params,
        address account,
        address token,
        uint256 walletRequestTokenAmount,
        bool isExecutionFeeFromLpVault
    ) external {
        uint256 requestId = UuidCreator.nextId(MINT_ID_KEY);

        Mint.Request storage mintRequest = Mint.create(requestId);
        mintRequest.account = account;
        mintRequest.stakeToken = params.stakeToken;
        mintRequest.requestToken = token;
        mintRequest.minStakeAmount = params.minStakeAmount;
        mintRequest.requestTokenAmount = params.requestTokenAmount;
        mintRequest.walletRequestTokenAmount = walletRequestTokenAmount;
        mintRequest.executionFee = params.executionFee;
        mintRequest.isCollateral = params.isCollateral;
        mintRequest.isExecutionFeeFromLpVault = isExecutionFeeFromLpVault;

        emit CreateMintEvent(requestId, mintRequest);
    }

    function executeMintStakeToken(
        uint256 requestId,
        Mint.Request memory mintRequest
    ) external returns (uint256 stakeAmount) {
        FeeRewardsProcess.updateAccountFeeRewards(mintRequest.account, mintRequest.stakeToken);
        if (CommonData.getStakeUsdToken() == mintRequest.stakeToken) {
            stakeAmount = _mintStakeUsd(mintRequest);
        } else if (CommonData.isStakeTokenSupport(mintRequest.stakeToken)) {
            stakeAmount = _mintStakeToken(mintRequest);
        } else {
            revert Errors.StakeTokenInvalid(mintRequest.stakeToken);
        }
        if (!mintRequest.isCollateral && mintRequest.walletRequestTokenAmount > 0) {
            IVault(address(this)).getLpVault().transferOut(
                mintRequest.requestToken,
                mintRequest.stakeToken,
                mintRequest.walletRequestTokenAmount
            );
        }

        Mint.remove(requestId);

        emit MintSuccessEvent(requestId, stakeAmount, mintRequest);
    }

    function cancelMintStakeToken(uint256 requestId, Mint.Request memory mintRequest, bytes32 reasonCode) external {
        if (mintRequest.walletRequestTokenAmount > 0) {
            VaultProcess.transferOut(
                mintRequest.isCollateral
                    ? IVault(address(this)).getPortfolioVaultAddress()
                    : IVault(address(this)).getLpVaultAddress(),
                mintRequest.requestToken,
                mintRequest.account,
                mintRequest.walletRequestTokenAmount
            );
        }
        Mint.remove(requestId);
        emit CancelMintEvent(requestId, mintRequest, reasonCode);
    }

    function validateAndDepositMintExecutionFee(
        address account,
        IStake.MintStakeTokenParams calldata params
    ) external returns (uint256, bool) {
        AppConfig.ChainConfig memory chainConfig = AppConfig.getChainConfig();
        GasProcess.validateExecutionFeeLimit(params.executionFee, chainConfig.mintGasFeeLimit);
        if (params.isNativeToken && params.walletRequestTokenAmount >= params.executionFee) {
            return (params.walletRequestTokenAmount - params.executionFee, true);
        }
        require(msg.value == params.executionFee, "mint with execution fee error!");
        AssetsProcess.depositToVault(
            AssetsProcess.DepositParams(
                account,
                chainConfig.wrapperToken,
                params.executionFee,
                AssetsProcess.DepositFrom.MANUAL,
                true
            )
        );
        return (params.walletRequestTokenAmount, false);
    }

    function _mintStakeToken(Mint.Request memory mintRequest) internal returns (uint256 stakeAmount) {
        if (mintRequest.requestTokenAmount > mintRequest.walletRequestTokenAmount) {
            _transferFromAccount(
                mintRequest.account,
                mintRequest.requestToken,
                mintRequest.requestTokenAmount - mintRequest.walletRequestTokenAmount
            );
        }

        StakingAccount.Props storage accountProps = StakingAccount.loadOrCreate(mintRequest.account);
        LpPool.Props storage pool = LpPool.load(mintRequest.stakeToken);
        pool.checkExists();
        AppPoolConfig.LpPoolConfig memory poolConfig = AppPoolConfig.getLpPoolConfig(mintRequest.stakeToken);
        ExecuteMintCache memory cache;
        cache.mintToken = mintRequest.requestToken;
        if (pool.baseToken != cache.mintToken) {
            revert Errors.MintTokenInvalid(mintRequest.stakeToken, mintRequest.requestToken);
        }
        cache.mintTokenDecimals = TokenUtils.decimals(cache.mintToken);
        uint256 minMintStakeAmount = AppPoolConfig.getStakeConfig().minPrecisionMultiple.mul(
            10 ** (cache.mintTokenDecimals - AppTradeTokenConfig.getTradeTokenConfig(cache.mintToken).precision)
        );
        if (mintRequest.requestTokenAmount < minMintStakeAmount) {
            revert Errors.MintStakeTokenTooSmall(minMintStakeAmount, mintRequest.requestTokenAmount);
        }

        cache.mintFee = FeeQueryProcess.calcMintOrRedeemFee(mintRequest.requestTokenAmount, poolConfig.mintFeeRate);
        FeeProcess.chargeMintOrRedeemFee(
            cache.mintFee,
            mintRequest.stakeToken,
            mintRequest.requestToken,
            mintRequest.account,
            FeeProcess.FEE_MINT,
            false
        );

        cache.mintTokenAmount = mintRequest.requestTokenAmount - cache.mintFee;
        cache.mintStakeAmount = _executeMintStakeToken(mintRequest, pool, cache.mintTokenAmount);
        accountProps.addStakeAmount(mintRequest.stakeToken, cache.mintStakeAmount);
        pool.addBaseToken(cache.mintTokenAmount);
        stakeAmount = cache.mintStakeAmount;
    }

    function _mintStakeUsd(Mint.Request memory mintRequest) internal returns (uint256 mintStakeAmount) {
        if (!UsdPool.isSupportStableToken(mintRequest.requestToken)) {
            revert Errors.MintTokenInvalid(mintRequest.stakeToken, mintRequest.requestToken);
        }
        uint8 mintTokenDecimals = TokenUtils.decimals(mintRequest.requestToken);
        uint256 minMintStakeAmount = AppPoolConfig.getStakeConfig().minPrecisionMultiple.mul(
            10 ** (mintTokenDecimals - AppTradeTokenConfig.getTradeTokenConfig(mintRequest.requestToken).precision)
        );
        if (mintRequest.requestTokenAmount < minMintStakeAmount) {
            revert Errors.MintStakeTokenTooSmall(minMintStakeAmount, mintRequest.requestTokenAmount);
        }
        if (mintRequest.walletRequestTokenAmount < mintRequest.requestTokenAmount) {
            _transferFromAccount(
                mintRequest.account,
                mintRequest.requestToken,
                mintRequest.requestTokenAmount - mintRequest.walletRequestTokenAmount
            );
        }

        uint256 mintFees = FeeQueryProcess.calcMintOrRedeemFee(
            mintRequest.requestTokenAmount,
            AppPoolConfig.getUsdPoolConfig().mintFeeRate
        );
        FeeProcess.chargeMintOrRedeemFee(
            mintFees,
            mintRequest.stakeToken,
            mintRequest.requestToken,
            mintRequest.account,
            FeeProcess.FEE_MINT,
            false
        );

        uint256 baseMintAmount = mintRequest.requestTokenAmount - mintFees;

        UsdPool.Props storage pool = UsdPool.load();
        mintStakeAmount = _executeMintStakeUsd(mintRequest, pool, baseMintAmount);

        StakingAccount.Props storage accountProps = StakingAccount.loadOrCreate(mintRequest.account);
        accountProps.addStakeUsdAmount(mintStakeAmount);
        pool.addStableToken(mintRequest.requestToken, baseMintAmount);
    }

    function _executeMintStakeToken(
        Mint.Request memory params,
        LpPool.Props storage pool,
        uint256 baseMintAmount
    ) internal returns (uint256) {
        uint256 mintStakeTokenAmount = computeStakeAmountFromMintToken(pool, baseMintAmount);
        if (params.minStakeAmount > 0 && mintStakeTokenAmount < params.minStakeAmount) {
            revert Errors.MintStakeTokenTooSmall(params.minStakeAmount, mintStakeTokenAmount);
        }
        StakeToken(params.stakeToken).mint(params.account, mintStakeTokenAmount);
        return mintStakeTokenAmount;
    }

    function _executeMintStakeUsd(
        Mint.Request memory params,
        UsdPool.Props storage pool,
        uint256 baseMintAmount
    ) internal returns (uint256) {
        address stableToken = params.requestToken;
        uint256 totalSupply = TokenUtils.totalSupply(params.stakeToken);
        uint8 tokenDecimals = TokenUtils.decimals(stableToken);
        uint8 stakeTokenDecimals = TokenUtils.decimals(params.stakeToken);
        uint256 poolValue = pool.getUsdPoolValue();
        uint256 mintStakeTokenAmount;
        if (totalSupply == 0 && poolValue == 0) {
            mintStakeTokenAmount = CalUtils.decimalsToDecimals(baseMintAmount, tokenDecimals, stakeTokenDecimals);
        } else if (totalSupply == 0 && poolValue > 0) {
            uint256 totalBaseMintAmount = baseMintAmount +
                CalUtils.usdToToken(poolValue, tokenDecimals, OracleProcess.getLatestUsdUintPrice(stableToken, true));
            mintStakeTokenAmount = CalUtils.decimalsToDecimals(totalBaseMintAmount, tokenDecimals, stakeTokenDecimals);
        } else if (poolValue == 0) {
            revert Errors.PoolValueIsZero();
        } else {
            uint256 baseMintAmountInUsd = CalUtils.tokenToUsd(
                baseMintAmount,
                tokenDecimals,
                OracleProcess.getLatestUsdUintPrice(stableToken, true)
            );
            mintStakeTokenAmount = totalSupply.mul(baseMintAmountInUsd).div(poolValue);
        }
        if (params.minStakeAmount > 0 && mintStakeTokenAmount < params.minStakeAmount) {
            revert Errors.MintStakeTokenTooSmall(params.minStakeAmount, mintStakeTokenAmount);
        }

        StakeToken(params.stakeToken).mint(params.account, mintStakeTokenAmount);

        return mintStakeTokenAmount;
    }

    function _transferFromAccount(address account, address token, uint256 needAmount) internal {
        Account.Props storage tradeAccount = Account.load(account);
        if (tradeAccount.getTokenAmount(token) < needAmount) {
            revert Errors.MintFailedWithBalanceNotEnough(account, token);
        }
        tradeAccount.subTokenIgnoreUsedAmount(token, needAmount, Account.UpdateSource.TRANSFER_TO_MINT);
        int256 availableValue = tradeAccount.getCrossAvailableValue();
        if (availableValue < 0) {
            revert Errors.MintFailedWithBalanceNotEnough(account, token);
        }
    }

    function computeStakeAmountFromMintToken(
        LpPool.Props storage pool,
        uint256 mintAmount
    ) public view returns (uint256) {
        uint256 totalSupply = TokenUtils.totalSupply(pool.stakeToken);
        uint8 tokenDecimals = TokenUtils.decimals(pool.baseToken);
        uint256 poolValue = pool.getPoolValue();
        uint256 mintStakeTokenAmount;
        if (totalSupply == 0 && poolValue == 0) {
            mintStakeTokenAmount = mintAmount;
        } else if (totalSupply == 0 && poolValue > 0) {
            mintStakeTokenAmount =
                mintAmount +
                CalUtils.usdToToken(
                    poolValue,
                    tokenDecimals,
                    OracleProcess.getLatestUsdUintPrice(pool.baseToken, true)
                );
        } else if (poolValue == 0) {
            revert Errors.PoolValueIsZero();
        } else {
            uint256 baseMintAmountInUsd = CalUtils.tokenToUsd(
                mintAmount,
                tokenDecimals,
                OracleProcess.getLatestUsdUintPrice(pool.baseToken, true)
            );
            mintStakeTokenAmount = totalSupply.mul(baseMintAmountInUsd).div(poolValue);
        }
        return mintStakeTokenAmount;
    }
}
