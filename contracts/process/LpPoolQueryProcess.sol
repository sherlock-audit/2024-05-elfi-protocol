// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";
import "../interfaces/IPool.sol";
import "../storage/LpPool.sol";
import "../storage/UsdPool.sol";
import "../storage/Market.sol";
import "../storage/Symbol.sol";
import "../storage/CommonData.sol";
import "../utils/Errors.sol";
import "../utils/CalUtils.sol";
import "../utils/TokenUtils.sol";
import "./OracleProcess.sol";

library LpPoolQueryProcess {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedSafeMath for int256;
    using LpPool for LpPool.Props;
    using UsdPool for UsdPool.Props;

    function getUsdPool() external view returns (IPool.UsdPoolInfo memory) {
        UsdPool.Props storage pool = UsdPool.load();
        if (pool.getStableTokens().length == 0) {
            IPool.UsdPoolInfo memory poolInfo;
            return poolInfo;
        }
        address stakeUsdToken = CommonData.getStakeUsdToken();
        uint256 totalSupply = IERC20(stakeUsdToken).totalSupply();
        address[] memory stableTokens = pool.getStableTokens();
        uint256[] memory tokensAvailableLiquidity = new uint256[](stableTokens.length);
        for (uint256 i; i < stableTokens.length; i++) {
            tokensAvailableLiquidity[i] = getUsdPoolAvailableLiquidity(pool, stableTokens[i]);
        }
        return
            IPool.UsdPoolInfo(
                stableTokens,
                pool.getStableTokenBalanceArray(),
                pool.getMaxWithdrawArray(),
                0,
                totalSupply,
                tokensAvailableLiquidity,
                pool.getAllBorrowingFees(),
                pool.apr,
                pool.totalClaimedRewards
            );
    }

    function getUsdPoolWithOracle(
        OracleProcess.OracleParam[] calldata oracles
    ) external view returns (IPool.UsdPoolInfo memory) {
        UsdPool.Props storage pool = UsdPool.load();
        if (pool.getStableTokens().length == 0) {
            IPool.UsdPoolInfo memory poolInfo;
            return poolInfo;
        }
        address stakeUsdToken = CommonData.getStakeUsdToken();
        uint256 totalSupply = IERC20(stakeUsdToken).totalSupply();
        address[] memory stableTokens = pool.getStableTokens();
        uint256[] memory tokensAvailableLiquidity = new uint256[](stableTokens.length);
        for (uint256 i; i < stableTokens.length; i++) {
            tokensAvailableLiquidity[i] = getUsdPoolAvailableLiquidity(pool, stableTokens[i]);
        }
        return
            IPool.UsdPoolInfo(
                stableTokens,
                pool.getStableTokenBalanceArray(),
                pool.getMaxWithdrawArray(),
                oracles.length > 0 ? getUsdPoolValue(pool, oracles) : 0,
                totalSupply,
                tokensAvailableLiquidity,
                pool.getAllBorrowingFees(),
                pool.apr,
                pool.totalClaimedRewards
            );
    }

    function getAllPools(OracleProcess.OracleParam[] calldata oracles) external view returns (IPool.PoolInfo[] memory) {
        address[] memory stakeTokens = CommonData.getAllStakeTokens();
        IPool.PoolInfo[] memory poolInfos = new IPool.PoolInfo[](stakeTokens.length);
        for (uint256 i; i < stakeTokens.length; i++) {
            poolInfos[i] = getPool(stakeTokens[i], oracles);
        }
        return poolInfos;
    }

    function getPoolValue(LpPool.Props storage pool) public view returns (uint256) {
        int256 poolValue = getPoolIntValue(pool);
        return poolValue <= 0 ? 0 : poolValue.toUint256();
    }

    function getPoolValue(
        LpPool.Props storage pool,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (uint256) {
        int256 poolValue = getPoolIntValue(pool, oracles);
        return poolValue <= 0 ? 0 : poolValue.toUint256();
    }

    function getPoolIntValue(LpPool.Props storage pool) public view returns (int256) {
        OracleProcess.OracleParam[] memory oracles;
        return getPoolIntValue(pool, oracles);
    }

    function getPoolIntValue(
        LpPool.Props storage pool,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (int256) {
        int256 value = 0;
        if (pool.baseTokenBalance.amount > 0 || pool.baseTokenBalance.unsettledAmount > 0) {
            int256 unPnl = getMarketUnPnl(pool.symbol, oracles, true, pool.baseToken, true);
            int256 baseTokenPrice = OracleProcess.getIntOraclePrices(oracles, pool.baseToken, true);
            value = CalUtils.tokenToUsdInt(
                (pool.baseTokenBalance.amount.toInt256() + pool.baseTokenBalance.unsettledAmount + unPnl),
                TokenUtils.decimals(pool.baseToken),
                baseTokenPrice
            );
        }
        address[] memory stableTokens = pool.getStableTokens();
        if (stableTokens.length > 0) {
            for (uint256 i; i < stableTokens.length; i++) {
                LpPool.TokenBalance storage tokenBalance = pool.stableTokenBalances[stableTokens[i]];
                if (tokenBalance.amount > 0 || tokenBalance.unsettledAmount > 0) {
                    int256 unPnl = getMarketUnPnl(pool.symbol, oracles, false, stableTokens[i], true);
                    value = value.add(
                        CalUtils.tokenToUsdInt(
                            (tokenBalance.amount.toInt256() +
                                tokenBalance.unsettledAmount -
                                tokenBalance.lossAmount.toInt256() +
                                unPnl),
                            TokenUtils.decimals(stableTokens[i]),
                            OracleProcess.getIntOraclePrices(oracles, stableTokens[i], true)
                        )
                    );
                }
            }
        }
        return value;
    }

    function getPoolAvailableLiquidity(LpPool.Props storage pool) external view returns (uint256) {
        OracleProcess.OracleParam[] memory oracles;
        return getPoolAvailableLiquidity(pool, oracles);
    }

    function getPoolAvailableLiquidity(
        LpPool.Props storage pool,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (uint256) {
        int256 baseTokenAmount = pool.baseTokenBalance.amount.toInt256() + pool.baseTokenBalance.unsettledAmount;
        if (baseTokenAmount < 0) {
            return 0;
        }

        address[] memory stableTokens = pool.getStableTokens();
        if (stableTokens.length > 0) {
            uint8 baseTokenDecimals = TokenUtils.decimals(pool.baseToken);
            int256 baseTokenPrice = OracleProcess.getIntOraclePrices(oracles, pool.baseToken, true);
            for (uint256 i; i < stableTokens.length; i++) {
                LpPool.TokenBalance storage tokenBalance = pool.stableTokenBalances[stableTokens[i]];
                if (
                    tokenBalance.lossAmount > 0 &&
                    tokenBalance.amount.toInt256() + tokenBalance.unsettledAmount < tokenBalance.lossAmount.toInt256()
                ) {
                    int256 tokenUsd = CalUtils.tokenToUsdInt(
                        tokenBalance.lossAmount.toInt256() -
                            tokenBalance.amount.toInt256() -
                            tokenBalance.unsettledAmount,
                        TokenUtils.decimals(stableTokens[i]),
                        OracleProcess.getIntOraclePrices(oracles, stableTokens[i], true)
                    );
                    int256 stableToBaseToken = CalUtils.usdToTokenInt(tokenUsd, baseTokenDecimals, baseTokenPrice);
                    if (baseTokenAmount > stableToBaseToken) {
                        baseTokenAmount -= stableToBaseToken;
                    } else {
                        baseTokenAmount = 0;
                    }
                }
            }
        }
        int256 availableTokenAmount = CalUtils.mulRate(baseTokenAmount, pool.getPoolLiquidityLimit().toInt256());
        return
            availableTokenAmount > pool.baseTokenBalance.holdAmount.toInt256()
                ? (availableTokenAmount - pool.baseTokenBalance.holdAmount.toInt256()).toUint256()
                : 0;
    }

    function getUsdPoolAvailableLiquidity(UsdPool.Props storage pool, address token) public view returns (uint256) {
        UsdPool.TokenBalance memory tokenBalance = pool.getStableTokenBalance(token);
        uint256 totalAmount = tokenBalance.amount + tokenBalance.unsettledAmount;
        uint256 availableTokenAmount = CalUtils.mulRate(totalAmount, UsdPool.getPoolLiquidityLimit());
        return availableTokenAmount > tokenBalance.holdAmount ? availableTokenAmount - tokenBalance.holdAmount : 0;
    }

    function getUsdPoolValue(UsdPool.Props storage pool) public view returns (uint256) {
        OracleProcess.OracleParam[] memory oracles;
        return getUsdPoolValue(pool, oracles);
    }

    function getUsdPoolValue(
        UsdPool.Props storage pool,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (uint256) {
        int256 poolValue = getUsdPoolIntValue(pool, oracles);
        return poolValue <= 0 ? 0 : poolValue.toUint256();
    }

    function getUsdPoolIntValue(UsdPool.Props storage pool) public view returns (int256) {
        OracleProcess.OracleParam[] memory oracles;
        return getUsdPoolIntValue(pool, oracles);
    }

    function getUsdPoolIntValue(
        UsdPool.Props storage pool,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (int256) {
        int256 value = 0;
        address[] memory stableTokens = pool.getStableTokens();
        if (stableTokens.length > 0) {
            for (uint256 i; i < stableTokens.length; i++) {
                UsdPool.TokenBalance storage tokenBalance = pool.stableTokenBalances[stableTokens[i]];
                if (tokenBalance.amount > 0 || tokenBalance.unsettledAmount > 0) {
                    value = value.add(
                        CalUtils.tokenToUsdInt(
                            (tokenBalance.amount.toInt256() + tokenBalance.unsettledAmount.toInt256()),
                            TokenUtils.decimals(stableTokens[i]),
                            OracleProcess.getIntOraclePrices(oracles, stableTokens[i], true)
                        )
                    );
                }
            }
        }
        return value;
    }

    function getMarketUnPnl(
        bytes32 symbol,
        OracleProcess.OracleParam[] memory oracles,
        bool isLong,
        address marginToken,
        bool pnlToken
    ) public view returns (int256) {
        Market.Props storage market = Market.load(symbol);
        Symbol.Props memory symbolProps = Symbol.load(symbol);
        Market.MarketPosition storage position = isLong ? market.longPosition : market.shortPositionMap[marginToken];
        if (position.openInterest == 0) {
            return 0;
        }
        int256 markPrice = OracleProcess.getIntOraclePrices(oracles, symbolProps.indexToken, true);
        if (position.entryPrice == markPrice.toUint256()) {
            return 0;
        }
        if (isLong) {
            int pnlInUsd = position.openInterest.toInt256().mul(markPrice.sub(position.entryPrice.toInt256())).div(
                position.entryPrice.toInt256()
            );
            if (pnlToken) {
                int256 marginTokenPrice = OracleProcess.getIntOraclePrices(oracles, marginToken, false);
                return -CalUtils.usdToTokenInt(pnlInUsd, TokenUtils.decimals(marginToken), marginTokenPrice);
            } else {
                return -pnlInUsd;
            }
        } else {
            int pnlInUsd = position.openInterest.toInt256().mul(position.entryPrice.toInt256().sub(markPrice)).div(
                position.entryPrice.toInt256()
            );
            if (pnlToken) {
                int256 marginTokenPrice = OracleProcess.getIntOraclePrices(oracles, marginToken, false);
                return -CalUtils.usdToTokenInt(pnlInUsd, TokenUtils.decimals(marginToken), marginTokenPrice);
            } else {
                return -pnlInUsd;
            }
        }
    }

    function getPool(
        address stakeToken,
        OracleProcess.OracleParam[] memory oracles
    ) public view returns (IPool.PoolInfo memory) {
        LpPool.Props storage pool = LpPool.load(stakeToken);
        IPool.PoolInfo memory result;
        if (!pool.isExists()) {
            return result;
        }
        address[] memory stableTokens = pool.getStableTokens();
        uint256 totalSupply = IERC20(stakeToken).totalSupply();
        result = IPool.PoolInfo(
            stakeToken,
            pool.stakeTokenName,
            pool.baseToken,
            pool.symbol,
            _convertPoolBalance(pool.baseTokenBalance),
            stableTokens,
            _convertPoolStableBalance(stableTokens, pool.stableTokenBalances),
            oracles.length > 0 ? getPoolValue(pool, oracles) : 0,
            oracles.length > 0 ? getPoolAvailableLiquidity(pool, oracles) : 0,
            0,
            totalSupply,
            pool.borrowingFee,
            pool.apr,
            pool.totalClaimedRewards
        );
        return result;
    }

    function _convertPoolBalance(
        LpPool.TokenBalance storage balance
    ) internal view returns (IPool.MintTokenBalance memory) {
        (address[] memory collateralTokens, uint256[] memory amounts) = LpPool.getCollateralTokenAmounts(
            balance.collateralTokenAmounts
        );
        return
            IPool.MintTokenBalance(
                balance.amount,
                balance.liability,
                balance.holdAmount,
                balance.unsettledAmount,
                balance.lossAmount,
                collateralTokens,
                amounts
            );
    }

    function _convertPoolStableBalance(
        address[] memory stableTokens,
        mapping(address => LpPool.TokenBalance) storage stableTokenBalances
    ) internal view returns (IPool.MintTokenBalance[] memory) {
        IPool.MintTokenBalance[] memory stableTokenBalanceArray = new IPool.MintTokenBalance[](stableTokens.length);
        for (uint256 i; i < stableTokens.length; i++) {
            stableTokenBalanceArray[i] = _convertPoolBalance(stableTokenBalances[stableTokens[i]]);
        }
        return stableTokenBalanceArray;
    }

}
