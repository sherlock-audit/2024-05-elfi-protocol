// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../utils/CalUtils.sol";
import "../utils/ChainUtils.sol";
import "../utils/Errors.sol";
import "./AppPoolConfig.sol";

library LpPool {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeMath for uint256;

    struct Props {
        address stakeToken;
        string stakeTokenName;
        address baseToken;
        bytes32 symbol;
        TokenBalance baseTokenBalance;
        EnumerableSet.AddressSet stableTokens;
        mapping(address => TokenBalance) stableTokenBalances;
        mapping(address => FeeRewards) tradingFeeRewards;
        BorrowingFee borrowingFee;
        uint256 apr;
        uint256 totalClaimedRewards;
    }

    struct TokenBalance {
        uint256 amount;
        uint256 liability;
        uint256 holdAmount;
        int256 unsettledAmount;
        uint256 lossAmount;
        EnumerableMap.AddressToUintMap collateralTokenAmounts;
    }

    struct FeeRewards {
        uint256 amount;
        uint256 unsettledAmount;
    }

    struct BorrowingFee {
        uint256 totalBorrowingFee;
        uint256 totalRealizedBorrowingFee;
        uint256 cumulativeBorrowingFeePerToken;
        uint256 lastUpdateTime;
    }

    struct PoolTokenUpdateEventCache {
        address stakeToken;
        address token;
        uint256 preAmount;
        uint256 preLiability;
        uint256 preHoldAmount;
        int256 preUnsettledAmount;
        uint256 preLossAmount;
        uint256 amount;
        uint256 liability;
        uint256 holdAmount;
        int256 unsettledAmount;
        uint256 lossAmount;
        uint256 updateBlock;
    }

    event PoolTokenUpdateEvent(
        address stakeToken,
        address token,
        uint256 preAmount,
        uint256 preLiability,
        uint256 preHoldAmount,
        int256 preUnsettledAmount,
        uint256 preLossAmount,
        uint256 amount,
        uint256 liability,
        uint256 holdAmount,
        int256 unsettledAmount,
        uint256 lossAmount,
        uint256 updateBlock
    );

    event PoolCollateralTokenUpdateEvent(
        address stakeToken,
        address collateral,
        uint256 preAmount,
        uint256 amount,
        uint256 updateBlock
    );

    event PoolBorrowingFeeUpdateEvent(address stakeToken, BorrowingFee borrowingFee);

    function load(address stakeToken) public pure returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.LpPool", stakeToken));

        assembly {
            self.slot := s
        }
    }

    function addBaseToken(Props storage self, uint256 amount) external {
        addBaseToken(self, amount, true);
    }

    function addBaseToken(Props storage self, uint256 amount, bool needEmitEvent) public {
        if (needEmitEvent) {
            PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
                self.stakeToken,
                self.baseToken,
                self.baseTokenBalance
            );
            self.baseTokenBalance.amount += amount;
            cache.amount = self.baseTokenBalance.amount;
            _emitPoolUpdateEvent(cache);
        } else {
            self.baseTokenBalance.amount += amount;
        }
    }

    function addCollateralBaseToken(
        Props storage self,
        uint256 amount,
        address collateral,
        uint256 collateralAmount
    ) external {
        TokenBalance storage balance = self.baseTokenBalance;
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(self.stakeToken, self.baseToken, balance);
        balance.amount += amount;
        balance.liability += amount;
        cache.amount = balance.amount;
        cache.liability = balance.liability;

        (bool exists, uint256 tokenAmount) = balance.collateralTokenAmounts.tryGet(collateral);
        if (exists) {
            balance.collateralTokenAmounts.set(collateral, tokenAmount + collateralAmount);
        } else {
            balance.collateralTokenAmounts.set(collateral, collateralAmount);
        }
        _emitPoolUpdateEvent(cache);
        emit PoolCollateralTokenUpdateEvent(
            self.stakeToken,
            collateral,
            tokenAmount,
            tokenAmount + collateralAmount,
            ChainUtils.currentBlock()
        );
    }

    function subBaseToken(Props storage self, uint256 amount) external {
        subBaseToken(self, amount, true);
    }

    function subBaseToken(Props storage self, uint256 amount, bool emitEvent) public {
        require(self.baseTokenBalance.amount >= amount, "base token amount less than sub amount!");
        if (emitEvent) {
            PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
                self.stakeToken,
                self.baseToken,
                self.baseTokenBalance
            );
            self.baseTokenBalance.amount -= amount;
            cache.amount = self.baseTokenBalance.amount;
            _emitPoolUpdateEvent(cache);
        } else {
            self.baseTokenBalance.amount -= amount;
        }
    }

    function subCollateralBaseToken(
        Props storage self,
        uint256 amount,
        address collateral,
        uint256 collateralAmount
    ) external {
        require(
            self.baseTokenBalance.amount >= amount && self.baseTokenBalance.liability >= amount,
            "sub failed with balance not enough"
        );

        TokenBalance storage balance = self.baseTokenBalance;
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(self.stakeToken, self.baseToken, balance);
        balance.amount -= amount;
        balance.liability -= amount;
        cache.amount = balance.amount;
        cache.liability = balance.liability;
        uint256 tokenAmount = balance.collateralTokenAmounts.get(collateral);
        if (tokenAmount == collateralAmount) {
            balance.collateralTokenAmounts.remove(collateral);
        } else {
            balance.collateralTokenAmounts.set(collateral, tokenAmount - collateralAmount);
        }

        _emitPoolUpdateEvent(cache);
        emit PoolCollateralTokenUpdateEvent(
            self.stakeToken,
            collateral,
            tokenAmount,
            tokenAmount - collateralAmount,
            ChainUtils.currentBlock()
        );
    }

    function holdBaseToken(Props storage self, uint256 amount) external {
        require(
            isHoldAmountAllowed(self.baseTokenBalance, getPoolLiquidityLimit(self), amount),
            "hold failed with balance not enough"
        );
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
            self.stakeToken,
            self.baseToken,
            self.baseTokenBalance
        );
        self.baseTokenBalance.holdAmount += amount;
        cache.holdAmount = self.baseTokenBalance.holdAmount;
        _emitPoolUpdateEvent(cache);
    }

    function unHoldBaseToken(Props storage self, uint256 amount) external {
        require(self.baseTokenBalance.holdAmount >= amount, "sub hold bigger than hold");
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
            self.stakeToken,
            self.baseToken,
            self.baseTokenBalance
        );
        self.baseTokenBalance.holdAmount -= amount;
        cache.holdAmount = self.baseTokenBalance.holdAmount;
        _emitPoolUpdateEvent(cache);
    }

    function addUnsettleBaseToken(Props storage self, int256 amount) external {
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
            self.stakeToken,
            self.baseToken,
            self.baseTokenBalance
        );
        self.baseTokenBalance.unsettledAmount += amount;
        cache.unsettledAmount = self.baseTokenBalance.unsettledAmount;
        _emitPoolUpdateEvent(cache);
    }

    function settleBaseToken(Props storage self, uint256 amount) external {
        int256 amountInt = amount.toInt256();
        require(self.baseTokenBalance.unsettledAmount >= amountInt, "settle base token overflow!");
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
            self.stakeToken,
            self.baseToken,
            self.baseTokenBalance
        );
        self.baseTokenBalance.unsettledAmount -= amountInt;
        self.baseTokenBalance.amount += amount;
        cache.unsettledAmount = self.baseTokenBalance.unsettledAmount;
        cache.amount = self.baseTokenBalance.amount;
        _emitPoolUpdateEvent(cache);
    }

    function addStableToken(Props storage self, address stableToken, uint256 amount) external {
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
            self.stakeToken,
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        if (self.stableTokens.contains(stableToken)) {
            self.stableTokenBalances[stableToken].amount += amount;
        } else {
            self.stableTokens.add(stableToken);
            self.stableTokenBalances[stableToken].amount = amount;
        }
        cache.amount = self.stableTokenBalances[stableToken].amount;
        _emitPoolUpdateEvent(cache);
    }

    function subStableToken(Props storage self, address stableToken, uint256 amount) external {
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
            self.stakeToken,
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].amount -= amount;
        cache.amount = self.stableTokenBalances[stableToken].amount;
        if (self.stableTokenBalances[stableToken].amount == 0) {
            self.stableTokens.remove(stableToken);
            delete self.stableTokenBalances[stableToken];
        }
        _emitPoolUpdateEvent(cache);
    }

    function holdStableToken(Props storage self, address stableToken, uint256 amount) external {
        require(
            isHoldAmountAllowed(self.stableTokenBalances[stableToken], getPoolLiquidityLimit(self), amount),
            "hold failed with balance not enough"
        );
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
            self.stakeToken,
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].holdAmount += amount;
        cache.holdAmount = self.stableTokenBalances[stableToken].holdAmount;
        _emitPoolUpdateEvent(cache);
    }

    function unHoldStableToken(Props storage self, address stableToken, uint256 amount) external {
        require(self.stableTokenBalances[stableToken].holdAmount < amount, "sub hold bigger than hold");
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
            self.stakeToken,
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].holdAmount -= amount;
        cache.holdAmount = self.stableTokenBalances[stableToken].holdAmount;
        _emitPoolUpdateEvent(cache);
    }

    function addUnsettleStableToken(Props storage self, address stableToken, int256 amount) external {
        if (!self.stableTokens.contains(stableToken)) {
            self.stableTokens.add(stableToken);
        }
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(
            self.stakeToken,
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].unsettledAmount += amount;
        cache.unsettledAmount = self.stableTokenBalances[stableToken].unsettledAmount;
        _emitPoolUpdateEvent(cache);
    }

    function settleStableToken(Props storage self, address stableToken, uint256 amount) external {
        if (!self.stableTokens.contains(stableToken)) {
            self.stableTokens.add(stableToken);
        }
        int256 amountInt = amount.toInt256();
        TokenBalance storage balance = self.stableTokenBalances[stableToken];
        require(balance.unsettledAmount >= amountInt, "settle stable token overflow!");
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(self.stakeToken, stableToken, balance);
        balance.unsettledAmount -= amountInt;
        balance.amount += amount;
        cache.unsettledAmount = balance.unsettledAmount;
        cache.amount = balance.amount;

        _emitPoolUpdateEvent(cache);
    }

    function addLossStableToken(Props storage self, address stableToken, uint256 amount) external {
        if (!self.stableTokens.contains(stableToken)) {
            self.stableTokens.add(stableToken);
        }
        TokenBalance storage balance = self.stableTokenBalances[stableToken];
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(self.stakeToken, stableToken, balance);
        balance.lossAmount += amount;
        cache.lossAmount = balance.lossAmount;
        _emitPoolUpdateEvent(cache);
    }

    function subLossStableToken(Props storage self, address stableToken, uint256 amount) external {
        if (!self.stableTokens.contains(stableToken)) {
            self.stableTokens.add(stableToken);
        }
        TokenBalance storage balance = self.stableTokenBalances[stableToken];
        require(balance.lossAmount >= amount, "sub loss stable token overflow!");
        PoolTokenUpdateEventCache memory cache = _convertBalanceToCache(self.stakeToken, stableToken, balance);
        balance.lossAmount -= amount;
        cache.lossAmount = balance.lossAmount;
        _emitPoolUpdateEvent(cache);
    }

    function getStableTokens(Props storage self) external view returns (address[] memory) {
        return self.stableTokens.values();
    }

    function getStableTokenBalance(
        Props storage self,
        address stableToken
    ) external view returns (TokenBalance storage) {
        return self.stableTokenBalances[stableToken];
    }

    function getPoolLiquidityLimit(Props storage self) public view returns (uint256) {
        return AppPoolConfig.getLpPoolConfig(self.stakeToken).poolLiquidityLimit;
    }

    function getCollateralTokenAmounts(
        EnumerableMap.AddressToUintMap storage collateralTokenAmounts
    ) external view returns (address[] memory tokens, uint256[] memory amounts) {
        tokens = collateralTokenAmounts.keys();
        amounts = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            amounts[i] = collateralTokenAmounts.get(tokens[i]);
        }
    }

    function getCollateralTokenAmount(Props storage self, address token) external view returns (uint256) {
        (bool exists, uint256 amount) = self.baseTokenBalance.collateralTokenAmounts.tryGet(token);
        return exists ? amount : 0;
    }

    function isSubAmountAllowed(Props storage self, address token, uint256 amount) internal view returns (bool) {
        TokenBalance storage balance = token == self.baseToken
            ? self.baseTokenBalance
            : self.stableTokenBalances[token];
        if (balance.amount < amount) {
            return false;
        }
        uint256 poolLiquidityLimit = getPoolLiquidityLimit(self);
        if (poolLiquidityLimit == 0) {
            return
                balance.amount.toInt256() + balance.unsettledAmount - balance.holdAmount.toInt256() >=
                amount.toInt256();
        } else {
            return
                CalUtils.mulRate(
                    balance.amount.toInt256() - amount.toInt256() + balance.unsettledAmount,
                    poolLiquidityLimit.toInt256()
                ) >= balance.holdAmount.toInt256();
        }
    }

    function isHoldAmountAllowed(
        TokenBalance storage balance,
        uint256 poolLiquidityLimit,
        uint256 amount
    ) public view returns (bool) {
        if (poolLiquidityLimit == 0) {
            return
                balance.amount.toInt256() + balance.unsettledAmount - balance.holdAmount.toInt256() >=
                amount.toInt256();
        } else {
            return
                CalUtils.mulRate(balance.amount.toInt256() + balance.unsettledAmount, poolLiquidityLimit.toInt256()) -
                    balance.holdAmount.toInt256() >=
                amount.toInt256();
        }
    }

    function checkExists(Props storage self) external view {
        if (self.baseToken == address(0)) {
            revert Errors.PoolNotExists();
        }
    }

    function isExists(Props storage self) external view returns (bool) {
        return self.baseToken != address(0);
    }

    function emitPoolBorrowingFeeUpdateEvent(Props storage self) external {
        emit PoolBorrowingFeeUpdateEvent(self.stakeToken, self.borrowingFee);
    }

    function _convertBalanceToCache(
        address stakeToken,
        address token,
        TokenBalance storage balance
    ) internal view returns (PoolTokenUpdateEventCache memory cache) {
        cache.stakeToken = stakeToken;
        cache.token = token;
        cache.preAmount = balance.amount;
        cache.preLiability = balance.liability;
        cache.preHoldAmount = balance.holdAmount;
        cache.preUnsettledAmount = balance.unsettledAmount;
        cache.preLossAmount = balance.lossAmount;
        cache.amount = balance.amount;
        cache.liability = balance.liability;
        cache.holdAmount = balance.holdAmount;
        cache.unsettledAmount = balance.unsettledAmount;
        cache.lossAmount = balance.lossAmount;
        cache.updateBlock = ChainUtils.currentBlock();
    }

    function _emitPoolUpdateEvent(PoolTokenUpdateEventCache memory cache) internal {
        emit PoolTokenUpdateEvent(
            cache.stakeToken,
            cache.token,
            cache.preAmount,
            cache.preLiability,
            cache.preHoldAmount,
            cache.preUnsettledAmount,
            cache.preLossAmount,
            cache.amount,
            cache.liability,
            cache.holdAmount,
            cache.unsettledAmount,
            cache.lossAmount,
            cache.updateBlock
        );
    }
}
