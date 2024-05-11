// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./OracleProcess.sol";
import "./MarketProcess.sol";
import "./LpPoolQueryProcess.sol";

library LpPoolProcess {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedSafeMath for int256;
    using LpPool for LpPool.Props;
    using LpPoolQueryProcess for LpPool.Props;
    using UsdPool for UsdPool.Props;

    function holdPoolAmount(address stakeToken, address token, uint256 amount, bool isLong) external {
        if (isLong) {
            LpPool.Props storage pool = LpPool.load(stakeToken);
            if (pool.getPoolAvailableLiquidity() < amount) {
                revert Errors.PoolAmountNotEnough(stakeToken, token);
            }
            pool.holdBaseToken(amount);
        } else {
            UsdPool.Props storage pool = UsdPool.load();
            if (
                !UsdPool.isHoldAmountAllowed(pool.stableTokenBalances[token], UsdPool.getPoolLiquidityLimit(), amount)
            ) {
                revert Errors.PoolAmountNotEnough(stakeToken, token);
            }
            pool.holdStableToken(token, amount);
        }
    }

    function updatePnlAndUnHoldPoolAmount(
        address stakeToken,
        address token,
        uint256 amount,
        int256 tokenPnl,
        uint256 addLiability
    ) external {
        LpPool.Props storage pool = LpPool.load(stakeToken);
        if (pool.baseToken == token) {
            pool.unHoldBaseToken(amount);
            if (tokenPnl < 0) {
                pool.subBaseToken((-tokenPnl).toUint256());
            } else if (addLiability == 0) {
                pool.addBaseToken(tokenPnl.toUint256());
            } else {
                uint256 uTokenPnl = tokenPnl.toUint256();
                pool.addBaseToken(uTokenPnl > addLiability ? uTokenPnl - addLiability : 0);
                pool.addUnsettleBaseToken(uTokenPnl > addLiability ? addLiability.toInt256() : tokenPnl);
            }
        } else {
            UsdPool.Props storage usdPool = UsdPool.load();
            usdPool.unHoldStableToken(token, amount);
            if (tokenPnl < 0) {
                uint256 uTokenPnl = (-tokenPnl).toUint256();
                pool.addLossStableToken(token, uTokenPnl);
                usdPool.subStableToken(token, uTokenPnl);
                usdPool.addUnsettleStableToken(token, uTokenPnl);
            } else if (addLiability == 0) {
                pool.addStableToken(token, tokenPnl.toUint256());
            } else {
                uint256 uTokenPnl = tokenPnl.toUint256();
                pool.addStableToken(token, uTokenPnl > addLiability ? uTokenPnl - addLiability : 0);
                pool.addUnsettleStableToken(token, uTokenPnl > addLiability ? addLiability.toInt256() : tokenPnl);
            }
        }
    }

    function validate(LpPool.Props storage pool) public view {
        if (LpPoolQueryProcess.getPoolIntValue(pool) < 0) {
            revert Errors.PoolValueLessThanZero();
        }
    }

    function subPoolAmount(LpPool.Props storage pool, address token, uint256 amount) external {
        if (!pool.isSubAmountAllowed(token, amount)) {
            revert Errors.PoolAmountNotEnough(pool.stakeToken, token);
        }
        if (pool.baseToken == token) {
            pool.subBaseToken(amount);
        } else {
            pool.subStableToken(token, amount);
        }
        validate(pool);
    }
}
