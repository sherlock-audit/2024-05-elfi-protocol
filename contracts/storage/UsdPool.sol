// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../utils/CalUtils.sol";
import "../utils/ChainUtils.sol";
import "../utils/TokenUtils.sol";
import "./AppPoolConfig.sol";

library UsdPool {
    bytes32 private constant _KEY = keccak256(abi.encode("xyz.elfi.storage.UsdPool"));

    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;
    using SafeCast for uint256;

    struct Props {
        EnumerableSet.AddressSet stableTokens;
        mapping(address => TokenBalance) stableTokenBalances;
        mapping(address => BorrowingFee) borrowingFees;
        uint256 apr;
        uint256 totalClaimedRewards;
    }

    struct TokenBalance {
        uint256 amount;
        uint256 holdAmount;
        uint256 unsettledAmount;
    }

    struct BorrowingFee {
        uint256 totalBorrowingFee;
        uint256 totalRealizedBorrowingFee;
        uint256 cumulativeBorrowingFeePerToken;
        uint256 lastUpdateTime;
    }

    struct UsdPoolTokenUpdateCache {
        address token;
        uint256 preAmount;
        uint256 preHoldAmount;
        uint256 preUnsettledAmount;
        uint256 amount;
        uint256 holdAmount;
        uint256 unsettledAmount;
        uint256 updateBlock;
    }

    event UsdPoolTokenUpdateEvent(
        address token,
        uint256 preAmount,
        uint256 preHoldAmount,
        uint256 preUnsettledAmount,
        uint256 amount,
        uint256 holdAmount,
        uint256 unsettledAmount,
        uint256 updateBlock
    );

    event UsdPoolBorrowingFeeUpdateEvent(BorrowingFee borrowingFee);

    function load() public pure returns (Props storage self) {
        bytes32 s = _KEY;

        assembly {
            self.slot := s
        }
    }

    function getUsdPoolConfig() internal view returns (AppPoolConfig.UsdPoolConfig memory) {
        return AppPoolConfig.getUsdPoolConfig();
    }

    function addStableToken(Props storage self, address stableToken, uint amount) external {
        require(self.stableTokens.contains(stableToken), "stable token not supported!");
        UsdPoolTokenUpdateCache memory cache = _convertBalanceToCache(
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].amount += amount;
        cache.amount = self.stableTokenBalances[stableToken].amount;
        _emitPoolUpdateEvent(cache);
    }

    function subStableToken(Props storage self, address stableToken, uint amount) external {
        require(isSubAmountAllowed(self, stableToken, amount), "sub failed with balance not enough");
        UsdPoolTokenUpdateCache memory cache = _convertBalanceToCache(
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].amount -= amount;
        cache.amount = self.stableTokenBalances[stableToken].amount;
        _emitPoolUpdateEvent(cache);
    }

    function holdStableToken(Props storage self, address stableToken, uint amount) external {
        require(
            isHoldAmountAllowed(self.stableTokenBalances[stableToken], getPoolLiquidityLimit(), amount),
            "hold failed with balance not enough"
        );
        UsdPoolTokenUpdateCache memory cache = _convertBalanceToCache(
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].holdAmount += amount;
        cache.holdAmount = self.stableTokenBalances[stableToken].holdAmount;
        _emitPoolUpdateEvent(cache);
    }

    function unHoldStableToken(Props storage self, address stableToken, uint256 amount) external {
        require(self.stableTokenBalances[stableToken].holdAmount >= amount, "sub hold bigger than hold");
        UsdPoolTokenUpdateCache memory cache = _convertBalanceToCache(
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].holdAmount -= amount;
        cache.holdAmount = self.stableTokenBalances[stableToken].holdAmount;
        _emitPoolUpdateEvent(cache);
    }

    function addUnsettleStableToken(Props storage self, address stableToken, uint256 amount) external {
        UsdPoolTokenUpdateCache memory cache = _convertBalanceToCache(
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].unsettledAmount += amount;
        cache.unsettledAmount = self.stableTokenBalances[stableToken].unsettledAmount;
        _emitPoolUpdateEvent(cache);
    }

    function settleStableToken(Props storage self, address stableToken, uint256 amount, bool updateAmount) external {
        if (!self.stableTokens.contains(stableToken)) {
            self.stableTokens.add(stableToken);
        }
        TokenBalance storage balance = self.stableTokenBalances[stableToken];
        require(balance.unsettledAmount >= amount, "xUsd settle stable token overflow!");
        UsdPoolTokenUpdateCache memory cache = _convertBalanceToCache(stableToken, balance);
        balance.unsettledAmount -= amount;
        cache.unsettledAmount = balance.unsettledAmount;
        if (updateAmount) {
            balance.amount += amount;
            cache.amount = balance.amount;
        }
        _emitPoolUpdateEvent(cache);
    }

    function addSupportStableTokens(Props storage self, address[] memory stableTokens) external {
        for (uint256 i; i < stableTokens.length; i++) {
            self.stableTokens.add(stableTokens[i]);
        }
    }

    function removeSupportStableToken(Props storage self, address stableToken) external {
        self.stableTokens.remove(stableToken);
    }

    function getPoolLiquidityLimit() public view returns (uint256) {
        return getUsdPoolConfig().poolLiquidityLimit;
    }

    function getBorrowingFees(Props storage self, address stableToken) external view returns (BorrowingFee storage) {
        return self.borrowingFees[stableToken];
    }

    function getStableTokens(Props storage self) external view returns (address[] memory) {
        return self.stableTokens.values();
    }

    function getSupportedStableTokens() external view returns (address[] memory) {
        Props storage self = load();
        return self.stableTokens.values();
    }

    function isSupportStableToken(address stableToken) external view returns (bool) {
        Props storage self = load();
        return self.stableTokens.contains(stableToken);
    }

    function getStableTokenBalance(
        Props storage self,
        address stableToken
    ) external view returns (TokenBalance memory) {
        return self.stableTokenBalances[stableToken];
    }

    function getStableTokenBalanceArray(Props storage self) external view returns (TokenBalance[] memory) {
        address[] memory tokens = self.stableTokens.values();
        TokenBalance[] memory balances = new TokenBalance[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            balances[i] = self.stableTokenBalances[tokens[i]];
        }
        return balances;
    }

    function getAllBorrowingFees(Props storage self) external view returns (BorrowingFee[] memory) {
        address[] memory tokens = self.stableTokens.values();
        BorrowingFee[] memory fees = new BorrowingFee[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            fees[i] = self.borrowingFees[tokens[i]];
        }
        return fees;
    }

    function getMaxWithdrawArray(Props storage self) external view returns (uint256[] memory) {
        address[] memory tokens = self.stableTokens.values();
        uint256[] memory maxWithdraws = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            maxWithdraws[i] = getMaxWithdraw(self, tokens[i]);
        }
        return maxWithdraws;
    }

    function getMaxWithdraw(Props storage self, address stableToken) public view returns (uint256) {
        TokenBalance storage balance = self.stableTokenBalances[stableToken];
        uint256 poolLiquidityLimit = getPoolLiquidityLimit();
        if (poolLiquidityLimit == 0) {
            return balance.amount - balance.holdAmount;
        } else {
            uint256 holdNeedAmount = CalUtils.divRate(balance.holdAmount, poolLiquidityLimit);
            return balance.amount > holdNeedAmount ? balance.amount - holdNeedAmount : 0;
        }
    }

    function getMaxAmountStableToken(Props storage self) external view returns (address token) {
        address[] memory tokens = self.stableTokens.values();
        uint256 maxAmount;
        for (uint256 i; i < tokens.length; i++) {
            uint256 tokenAmount = CalUtils.decimalsToDecimals(
                self.stableTokenBalances[tokens[i]].amount,
                TokenUtils.decimals(tokens[i]),
                18
            );
            if (tokenAmount >= maxAmount) {
                maxAmount = tokenAmount;
                token = tokens[i];
            }
        }
    }

    function isSubAmountAllowed(Props storage self, address stableToken, uint256 amount) public view returns (bool) {
        TokenBalance storage balance = self.stableTokenBalances[stableToken];
        if (balance.amount < amount) {
            return false;
        }
        uint256 poolLiquidityLimit = getPoolLiquidityLimit();
        if (poolLiquidityLimit == 0) {
            return balance.amount - balance.holdAmount >= amount;
        } else {
            return CalUtils.mulRate(balance.amount - amount, poolLiquidityLimit) >= balance.holdAmount;
        }
    }

    function isHoldAmountAllowed(
        TokenBalance memory balance,
        uint256 poolLiquidityLimit,
        uint256 amount
    ) internal pure returns (bool) {
        if (poolLiquidityLimit == 0) {
            return balance.amount + balance.unsettledAmount - balance.holdAmount >= amount;
        } else {
            return
                CalUtils.mulRate(balance.amount + balance.unsettledAmount, poolLiquidityLimit) - balance.holdAmount >=
                amount;
        }
    }

    function emitPoolBorrowingFeeUpdateEvent(Props storage self, address stableToken) external {
        emit UsdPoolBorrowingFeeUpdateEvent(self.borrowingFees[stableToken]);
    }

    function _convertBalanceToCache(
        address token,
        TokenBalance storage balance
    ) internal view returns (UsdPoolTokenUpdateCache memory cache) {
        cache.token = token;
        cache.preAmount = balance.amount;
        cache.preHoldAmount = balance.holdAmount;
        cache.preUnsettledAmount = balance.unsettledAmount;
        cache.amount = balance.amount;
        cache.holdAmount = balance.holdAmount;
        cache.unsettledAmount = balance.unsettledAmount;
        cache.updateBlock = ChainUtils.currentBlock();
    }

    function _emitPoolUpdateEvent(UsdPoolTokenUpdateCache memory cache) internal {
        emit UsdPoolTokenUpdateEvent(
            cache.token,
            cache.preAmount,
            cache.preHoldAmount,
            cache.preUnsettledAmount,
            cache.amount,
            cache.holdAmount,
            cache.unsettledAmount,
            cache.updateBlock
        );
    }
}
