// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../utils/CalUtils.sol";
import "../utils/ChainUtils.sol";
import "../utils/TokenUtils.sol";
import "./AppPoolConfig.sol";

/// @title Account Storage
/// @dev Library for USD pool storage and management
library UsdPool {
    bytes32 private constant _KEY = keccak256(abi.encode("xyz.elfi.storage.UsdPool"));

    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;
    using SafeCast for uint256;

    /// @dev Struct to store the USD pool information.
    /// @param stableTokens Set of supported stable tokens for the USD pool.
    /// @param stableTokenBalances Mapping of stable token addresses to their balances.
    /// @param borrowingFees Mapping of token addresses to their borrowing fees.
    /// @param apr Annual percentage rate (APR) of the USD pool.
    /// @param totalClaimedRewards Total rewards claimed from the USD pool.
    struct Props {
        EnumerableSet.AddressSet stableTokens;
        mapping(address => TokenBalance) stableTokenBalances;
        mapping(address => BorrowingFee) borrowingFees;
        uint256 apr;
        uint256 totalClaimedRewards;
    }

    /// @dev Struct to store token balance details.
    /// @param amount Total amount of the token (USDC,USDT,DAI...).
    /// @param holdAmount Token amount that is currently held by trader.
    /// @param unsettledAmount Unsettled amount, When a user makes a profit by shorting, resulting in a loss for the USD pool. 
    ///        Losses will be recorded in the corresponding elfToken pool. The USD pool will record them as unsettled, waiting for the elfToken pool to reimburse
    struct TokenBalance {
        uint256 amount;
        uint256 holdAmount;
        uint256 unsettledAmount;
    }

    /// @dev Struct to store borrowing fee details.
    /// @param totalBorrowingFee The total amount of borrowing fees accumulated
    /// @param totalRealizedBorrowingFee The total amount of borrowing fees that have been realized
    /// @param cumulativeBorrowingFeePerToken The cumulative borrowing fee per token
    /// @param lastUpdateTime The last time the borrowing fee were updated
    struct BorrowingFee {
        uint256 totalBorrowingFee;
        uint256 totalRealizedBorrowingFee;
        uint256 cumulativeBorrowingFeePerToken;
        uint256 lastUpdateTime;
    }

    // @dev Struct to cache USD pool token update data
    /// @param token The address of the token
    /// @param preAmount The previous amount of the token
    /// @param preHoldAmount The previous hold amount of the token
    /// @param preUnsettledAmount The previous unsettled amount of the token
    /// @param amount The current amount of the token
    /// @param holdAmount The current hold amount of the token
    /// @param unsettledAmount The current unsettled amount of the token
    /// @param updateBlock The block number when the update occurred
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

    /// @dev Event emitted when the USD pool token update occurs
    /// @param token The address of the token
    /// @param preAmount The previous amount of the token
    /// @param preHoldAmount The previous hold amount of the token
    /// @param preUnsettledAmount The previous unsettled amount of the token
    /// @param amount The current amount of the token
    /// @param holdAmount The current hold amount of the token
    /// @param unsettledAmount The current unsettled amount of the token
    /// @param updateBlock The block number when the update occurred
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

    /// @dev Loads the storage slot for the UsdPool.
    /// @return self The storage reference to the UsdPool properties.
    function load() public pure returns (Props storage self) {
        bytes32 s = _KEY;

        assembly {
            self.slot := s
        }
    }

    /// @dev Retrieves the USD pool configuration.
    /// @return The USD pool configuration.
    function getUsdPoolConfig() internal view returns (AppPoolConfig.UsdPoolConfig memory) {
        return AppPoolConfig.getUsdPoolConfig();
    }

    /// @dev Adds a stable token to the pool.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token to add.
    /// @param amount The amount of the stable token to add.
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

    /// @dev Subtracts a stable token from the pool.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token to subtract.
    /// @param amount The amount of the stable token to subtract.
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

    /// @dev Holds a stable token in the pool.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token to hold.
    /// @param amount The amount of the stable token to hold.
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

    /// @dev UnHolds a stable token in the pool.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token to unHold.
    /// @param amount The amount of the stable token to unHold.
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

    /// @dev Adds an unsettled stable token to the pool.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token to add.
    /// @param amount The amount of the stable token to add.
    function addUnsettleStableToken(Props storage self, address stableToken, uint256 amount) external {
        UsdPoolTokenUpdateCache memory cache = _convertBalanceToCache(
            stableToken,
            self.stableTokenBalances[stableToken]
        );
        self.stableTokenBalances[stableToken].unsettledAmount += amount;
        cache.unsettledAmount = self.stableTokenBalances[stableToken].unsettledAmount;
        _emitPoolUpdateEvent(cache);
    }

    /// @dev Settles a stable token in the pool.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token to settle.
    /// @param amount The amount of the stable token to settle.
    /// @param updateAmount Whether to update the amount of the stable token.
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

    /// @dev Adds support for multiple stable tokens.
    /// @param self UsdPool.Props
    /// @param stableTokens The array of stable token addresses to add.
    function addSupportStableTokens(Props storage self, address[] memory stableTokens) external {
        for (uint256 i; i < stableTokens.length; i++) {
            self.stableTokens.add(stableTokens[i]);
        }
    }

    /// @dev Removes support for a stable token.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token to remove.
    function removeSupportStableToken(Props storage self, address stableToken) external {
        self.stableTokens.remove(stableToken);
    }

    /// @dev Retrieves the pool liquidity limit.
    /// @return The pool liquidity limit.
    function getPoolLiquidityLimit() public view returns (uint256) {
        return getUsdPoolConfig().poolLiquidityLimit;
    }

    /// @dev Retrieves the borrowing fees for a stable token.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token.
    /// @return The borrowing fee for the stable token.
    function getBorrowingFees(Props storage self, address stableToken) external view returns (BorrowingFee storage) {
        return self.borrowingFees[stableToken];
    }

    /// @dev Retrieves the list of stable tokens in the pool.
    /// @param self UsdPool.Props
    /// @return The array of stable token addresses.
    function getStableTokens(Props storage self) external view returns (address[] memory) {
        return self.stableTokens.values();
    }

    /// @dev Retrieves the list of supported stable tokens.
    /// @return The array of supported stable token addresses.
    function getSupportedStableTokens() external view returns (address[] memory) {
        Props storage self = load();
        return self.stableTokens.values();
    }

    /// @dev Checks if a stable token is supported.
    /// @param stableToken The address of the stable token.
    /// @return True if the stable token is supported, false otherwise.
    function isSupportStableToken(address stableToken) external view returns (bool) {
        Props storage self = load();
        return self.stableTokens.contains(stableToken);
    }

    /// @dev Retrieves the balance of a stable token.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token.
    /// @return The balance of the stable token.
    function getStableTokenBalance(
        Props storage self,
        address stableToken
    ) external view returns (TokenBalance memory) {
        return self.stableTokenBalances[stableToken];
    }

    /// @dev Retrieves the balances of all stable tokens.
    /// @param self UsdPool.Props
    /// @return The array of stable token balances.
    function getStableTokenBalanceArray(Props storage self) external view returns (TokenBalance[] memory) {
        address[] memory tokens = self.stableTokens.values();
        TokenBalance[] memory balances = new TokenBalance[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            balances[i] = self.stableTokenBalances[tokens[i]];
        }
        return balances;
    }

    /// @dev Retrieves the borrowing fees for all stable tokens.
    /// @param self UsdPool.Props
    /// @return The array of borrowing fees.
    function getAllBorrowingFees(Props storage self) external view returns (BorrowingFee[] memory) {
        address[] memory tokens = self.stableTokens.values();
        BorrowingFee[] memory fees = new BorrowingFee[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            fees[i] = self.borrowingFees[tokens[i]];
        }
        return fees;
    }

    /// @dev Retrieves the maximum withdrawal amounts for all stable tokens.
    /// @param self UsdPool.Props
    /// @return The array of maximum withdrawal amounts.
    function getMaxWithdrawArray(Props storage self) external view returns (uint256[] memory) {
        address[] memory tokens = self.stableTokens.values();
        uint256[] memory maxWithdraws = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            maxWithdraws[i] = getMaxWithdraw(self, tokens[i]);
        }
        return maxWithdraws;
    }

    /// @dev Retrieves the maximum withdrawal amount for a stable token.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token.
    /// @return The maximum withdrawal amount.
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

    /// @dev Retrieves the stable token with the maximum amount.
    /// @param self UsdPool.Props
    /// @return token The address of the stable token with the maximum amount.
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

    /// @dev Checks if a subtraction amount is allowed for a stable token.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token.
    /// @param amount The amount to subtract.
    /// @return True if the subtraction amount is allowed, false otherwise.
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

    /// @dev Checks if a hold amount is allowed for a stable token.
    /// @param balance The balance of the stable token.
    /// @param poolLiquidityLimit The pool liquidity limit.
    /// @param amount The amount to hold.
    /// @return True if the hold amount is allowed, false otherwise.
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

    /// @dev Emits an event for updating the borrowing fee of a stable token.
    /// @param self UsdPool.Props
    /// @param stableToken The address of the stable token.
    function emitPoolBorrowingFeeUpdateEvent(Props storage self, address stableToken) external {
        emit UsdPoolBorrowingFeeUpdateEvent(self.borrowingFees[stableToken]);
    }

    /// @dev Converts a token balance to a cache structure.
    /// @param token The address of the token.
    /// @param balance The balance of the token.
    /// @return cache The cache structure containing the token balance information.
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

    /// @dev Emits an event for updating the pool.
    /// @param cache The cache structure containing the token balance information.
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
