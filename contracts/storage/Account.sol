// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./CommonData.sol";
import "./AppTradeTokenConfig.sol";
import "../utils/Errors.sol";

/// @title Account Storage
/// @dev Library for account storage and management
library Account {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;
    using CommonData for CommonData.Props;

    /// @dev Struct representing the account information
    /// @param owner address of the trade account
    /// @param orderHoldInUsd Total value held by order in USD currently
    /// @param tokens Set of tokens associated with the trade account
    /// @param tokenBalances tokens Mapping of token addresses to their balances
    /// @param positions Set of positions held by this account
    /// @param orders Set of orders placed by this account
    struct Props {
        address owner;
        uint256 orderHoldInUsd;
        EnumerableSet.AddressSet tokens;
        mapping(address => Account.TokenBalance) tokenBalances;
        EnumerableSet.Bytes32Set positions;
        EnumerableSet.UintSet orders;
    }

    /// @dev Struct used for storing the specific token information
    /// @param amount Total amount of the token
    /// amount will increase when deposit
    /// amount will decrease when redeem or repay liability
    /// @param usedAmount Amount of the token that is used
    /// usedAmount will increase when increasing margin
    /// usedAmount will decrease when reducing margin
    /// @param interest Interest earned on the token
    /// @param liability Liability of this token,
    /// Liability will increase when increasing position if the token balance is insufficient.
    /// Liability will be repaid when decreasing position.
    struct TokenBalance {
        uint256 amount;
        uint256 usedAmount;
        uint256 interest;
        uint256 liability;
    }

    /// @dev Source type for account token Update event
    enum UpdateSource {
        DEFAULT,
        DEPOSIT,
        WITHDRAW,
        SETTLE_FEE,
        SETTLE_PNL,
        DECREASE_POSITION,
        INCREASE_POSITION,
        UPDATE_POSITION_MARGIN,
        UPDATE_LEVERAGE,
        CHARGE_OPEN_FEE,
        CHARGE_CLOSE_FEE,
        TRANSFER_TO_MINT,
        CHARGE_EXECUTION_FEE,
        LIQUIDATE_LIABILITY,
        LIQUIDATE_CLEAN
    }

    event AccountTokenUpdateEvent(
        address account,
        address token,
        TokenBalance preBalance,
        TokenBalance balance,
        UpdateSource source
    );

    event AccountOrderHoldInUsdUpdateEvent(address account, uint256 preOrderHoldInUsd, uint256 orderHoldInUsd);

    event AccountCrossModeUpdateEvent(address account, bool isCrossMargin);

    /// @dev Loads the account storage for a given account address.
    /// @param owner The address of the account owner.
    /// @return self The account storage
    function load(address owner) public pure returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.Account", owner));
        assembly {
            self.slot := s
        }
    }

    /// @dev Loads or creates the account storage for a given account address.
    /// @param owner The address of the account owner.
    /// @return self The account storage
    function loadOrCreate(address owner) public returns (Props storage) {
        Props storage self = load(owner);
        if (self.owner == address(0)) {
            self.owner = owner;
        }
        return self;
    }

    /// @dev Adds a specified amount to the order hold in USD.
    /// @param self The account storage
    /// @param holdInUsd The amount to add to the order hold in USD.
    function addOrderHoldInUsd(Props storage self, uint256 holdInUsd) external {
        uint256 preOrderHoldInUsd = self.orderHoldInUsd;
        self.orderHoldInUsd += holdInUsd;
        emit AccountOrderHoldInUsdUpdateEvent(self.owner, preOrderHoldInUsd, self.orderHoldInUsd);
    }

    /// @dev Subtracts a specified amount from the order hold in USD.
    /// @param self The account storage
    /// @param holdInUsd The amount to subtract from the order hold in USD.
    function subOrderHoldInUsd(Props storage self, uint256 holdInUsd) external {
        require(self.orderHoldInUsd >= holdInUsd, "orderHoldInUsd is smaller than holdInUsd");
        uint256 preOrderHoldInUsd = self.orderHoldInUsd;
        self.orderHoldInUsd -= holdInUsd;
        emit AccountOrderHoldInUsdUpdateEvent(self.owner, preOrderHoldInUsd, self.orderHoldInUsd);
    }

    /// @dev Adds a specified amount of tokens to the account.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to add.
    function addToken(Props storage self, address token, uint256 amount) external {
        addToken(self, token, amount, UpdateSource.DEFAULT);
    }

    /// @dev Adds a specified amount of tokens to the account with a specified update source.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to add.
    /// @param source The source of the update.
    function addToken(Props storage self, address token, uint256 amount, UpdateSource source) public {
        if (!self.tokens.contains(token)) {
            self.tokens.add(token);
        }
        TokenBalance storage balance = self.tokenBalances[token];
        TokenBalance memory preBalance = balance;
        balance.amount += amount;
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, balance, source);
    }

    /// @dev Subtracts a specified amount of tokens from the account.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to subtract.
    function subToken(Props storage self, address token, uint256 amount) external {
        subToken(self, token, amount, UpdateSource.DEFAULT);
    }

    /// @dev Subtracts a specified amount of tokens from the account with a specified update source.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to subtract.
    /// @param source The source of the update.
    function subToken(Props storage self, address token, uint256 amount, UpdateSource source) public {
        require(self.tokens.contains(token), "token not exists!");
        require(self.tokenBalances[token].amount >= amount, "token amount not enough!");
        require(
            self.tokenBalances[token].amount >= self.tokenBalances[token].usedAmount + amount,
            "token amount exclude used amount not enough!"
        );
        TokenBalance memory preBalance = self.tokenBalances[token];
        self.tokenBalances[token].amount -= amount;
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, self.tokenBalances[token], source);
    }

    /// @dev Subtracts a specified amount of tokens from the account, ignoring the used amount.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to subtract.
    function subTokenIgnoreUsedAmount(Props storage self, address token, uint256 amount) external {
        subTokenIgnoreUsedAmount(self, token, amount, UpdateSource.DEFAULT);
    }

    /// @dev Subtracts a specified amount of tokens from the account, ignoring the used amount, with a specified update source.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to subtract.
    /// @param source The source of the update.
    function subTokenIgnoreUsedAmount(Props storage self, address token, uint256 amount, UpdateSource source) public {
        require(self.tokens.contains(token), "token not exists!");
        require(self.tokenBalances[token].amount >= amount, "token amount not enough!");
        TokenBalance memory preBalance = self.tokenBalances[token];
        self.tokenBalances[token].amount -= amount;
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, self.tokenBalances[token], source);
    }

    /// @dev Subtracts a specified amount of tokens from the account and updates the liability.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to subtract.
    /// @return liability The updated liability amount.
    function subTokenWithLiability(
        Props storage self,
        address token,
        uint256 amount
    ) external returns (uint256 liability) {
        return subTokenWithLiability(self, token, amount, UpdateSource.DEFAULT);
    }

    /// @dev Subtracts a specified amount of tokens from the account and updates the liability with a specified update source.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to subtract.
    /// @param source The source of the update.
    /// @return liability The updated liability amount.
    function subTokenWithLiability(
        Props storage self,
        address token,
        uint256 amount,
        UpdateSource source
    ) public returns (uint256 liability) {
        TokenBalance storage balance = self.tokenBalances[token];
        TokenBalance memory preBalance = balance;
        if (balance.amount >= amount) {
            balance.amount -= amount;
            liability = 0;
        } else if (balance.amount > 0) {
            liability = amount - balance.amount;
            balance.liability += liability;
            balance.usedAmount += liability;
            balance.amount = 0;
        } else {
            balance.liability += amount;
            balance.usedAmount += amount;
            liability = amount;
        }
        CommonData.load().addTokenLiability(token, liability);
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, balance, source);
    }

    /// @dev Uses a specified amount of tokens from the account.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to use.
    /// @return useFromBalance The amount used from the balance.
    function useToken(Props storage self, address token, uint256 amount) external returns (uint256 useFromBalance) {
        return useToken(self, token, amount, false, UpdateSource.DEFAULT);
    }

    /// @dev Uses a specified amount of tokens from the account with a specified update source.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to use.
    /// @param isCheck Whether to check the amount.
    /// @param source The source of the update.
    /// @return useFromBalance The amount used from the balance.
    function useToken(
        Props storage self,
        address token,
        uint256 amount,
        bool isCheck,
        UpdateSource source
    ) public returns (uint256 useFromBalance) {
        if (!self.tokens.contains(token)) {
            self.tokens.add(token);
        }
        TokenBalance storage balance = self.tokenBalances[token];
        require(!isCheck || balance.amount >= balance.usedAmount + amount, "use token failed with amount not enough");
        TokenBalance memory preBalance = balance;
        if (balance.amount >= balance.usedAmount + amount) {
            balance.usedAmount += amount;
            useFromBalance = amount;
        } else if (balance.amount > balance.usedAmount) {
            useFromBalance = balance.amount - balance.usedAmount;
            balance.usedAmount += amount;
        } else {
            balance.usedAmount += amount;
            useFromBalance = 0;
        }
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, balance, source);
    }

    /// @dev UnUses a specified amount of tokens from the account.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to unUse.
    function unUseToken(Props storage self, address token, uint256 amount) public {
        unUseToken(self, token, amount, UpdateSource.DEFAULT);
    }

    /// @dev UnUses a specified amount of tokens from the account with a specified update source.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param amount The amount of tokens to unUse.
    /// @param source The source of the update.
    function unUseToken(Props storage self, address token, uint256 amount, UpdateSource source) public {
        require(self.tokens.contains(token), "token not exists!");
        require(self.tokenBalances[token].usedAmount >= amount, "unUse overflow!");
        TokenBalance memory preBalance = self.tokenBalances[token];
        self.tokenBalances[token].usedAmount -= amount;
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, self.tokenBalances[token], source);
    }

    /// @dev Repays the liability for a specified token.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @return repayAmount The amount repaid.
    function repayLiability(Props storage self, address token) external returns (uint256 repayAmount) {
        return repayLiability(self, token, UpdateSource.DEFAULT);
    }

    /// @dev Repays the liability for a specified token with a specified update source.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param source The source of the update.
    /// @return repayAmount The amount repaid.
    function repayLiability(
        Props storage self,
        address token,
        UpdateSource source
    ) public returns (uint256 repayAmount) {
        TokenBalance storage balance = self.tokenBalances[token];
        if (balance.liability > 0 && balance.amount > 0) {
            TokenBalance memory preBalance = balance;
            repayAmount = balance.amount >= balance.liability ? balance.liability : balance.amount;
            balance.amount -= repayAmount;
            balance.liability -= repayAmount;
            balance.usedAmount -= repayAmount;
            CommonData.load().subTokenLiability(token, repayAmount);
            emit AccountTokenUpdateEvent(self.owner, token, preBalance, balance, source);
        }
    }

    /// @dev Clears the liability for a specified token.
    /// @param self The account storage
    /// @param token The address of the token.
    function clearLiability(Props storage self, address token) external {
        clearLiability(self, token, UpdateSource.DEFAULT);
    }

    /// @dev Clears the liability for a specified token with a specified update source.
    /// @param self The account storage
    /// @param token The address of the token.
    /// @param source The source of the update.
    function clearLiability(Props storage self, address token, UpdateSource source) public {
        TokenBalance storage balance = self.tokenBalances[token];
        TokenBalance memory preBalance = balance;
        CommonData.load().subTokenLiability(token, balance.liability);
        balance.usedAmount -= balance.liability;
        balance.liability = 0;
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, balance, source);
    }

    /// @dev Adds a position to the account.
    /// @param self The account storage
    /// @param position The position to add.
    function addPosition(Props storage self, bytes32 position) external {
        if (!self.positions.contains(position)) {
            self.positions.add(position);
        }
    }

    /// @dev Deletes a position from the account.
    /// @param self The account storage
    /// @param position The position to delete.
    function delPosition(Props storage self, bytes32 position) external {
        self.positions.remove(position);
    }

    /// @dev Checks if the account exists.
    /// @param self The account storage
    function checkExists(Props storage self) external view {
        if (self.owner == address(0)) {
            revert Errors.AccountNotExist();
        }
    }

    /// @dev Checks if the account exists.
    /// @param self The account storage
    /// @return True if the account exists, false otherwise.
    function isExists(Props storage self) external view returns (bool) {
        return self.owner != address(0);
    }

    /// @dev Gets all positions of the account.
    /// @param self The account storage
    /// @return An array of all positions.
    function getAllPosition(Props storage self) external view returns (bytes32[] memory) {
        return self.positions.values();
    }

    /// @dev Checks if the account has any positions.
    /// @param self The account storage
    /// @return True if the account has positions, false otherwise.
    function hasPosition(Props storage self) external view returns (bool) {
        return self.positions.length() > 0;
    }

    /// @dev Checks if the account has a specific position.
    /// @param self The account storage
    /// @param key The position key to check.
    /// @return True if the account has the position, false otherwise.
    function hasPosition(Props storage self, bytes32 key) external view returns (bool) {
        return self.positions.contains(key);
    }

    /// @dev Gets all orders of the account.
    /// @param self The account storage
    /// @return An array of all orders.
    function getAllOrders(Props storage self) external view returns (uint256[] memory) {
        return self.orders.values();
    }

    /// @dev Checks if the account has any orders.
    /// @param self The account storage
    /// @return True if the account has orders, false otherwise.
    function hasOrder(Props storage self) external view returns (bool) {
        return self.orders.length() > 0;
    }

    /// @dev Checks if the account has any orders other than a specific order.
    /// @param self The account storage
    /// @param orderId The order ID to check.
    /// @return True if the account has other orders, false otherwise.
    function hasOtherOrder(Props storage self, uint256 orderId) external view returns (bool) {
        uint256[] memory orderIds = self.orders.values();
        for (uint256 i; i < orderIds.length; i++) {
            if (orderIds[i] != orderId) {
                return true;
            }
        }
        return false;
    }

    /// @dev Adds an order to the account.
    /// @param self The account storage
    /// @param orderId The order ID to add.
    function addOrder(Props storage self, uint256 orderId) external {
        if (!self.orders.contains(orderId)) {
            self.orders.add(orderId);
        }
    }

    /// @dev Deletes an order from the account.
    /// @param self The account storage
    /// @param orderId The order ID to delete.
    function delOrder(Props storage self, uint256 orderId) external {
        self.orders.remove(orderId);
    }

    /// @dev Gets all orders of the account.
    /// @param self The account storage
    /// @return An array of all orders.
    function getOrders(Props storage self) external view returns (uint256[] memory) {
        return self.orders.values();
    }

    /// @dev Gets all tokens of the account.
    /// @param self The account storage
    /// @return An array of all token addresses.
    function getTokens(Props storage self) public view returns (address[] memory) {
        return self.tokens.values();
    }

    /// @dev Gets all tokens of the account sorted by discount.
    /// @param self The account storage
    /// @return An array of all token addresses sorted
    function getSortedTokensByDiscount(Props storage self) external view returns (address[] memory) {
        address[] memory tokens = self.tokens.values();
        AppTradeTokenConfig.TradeTokenConfig[] memory tokenConfigs = new AppTradeTokenConfig.TradeTokenConfig[](
            tokens.length
        );
        for (uint256 i; i < tokens.length; i++) {
            tokenConfigs[i] = AppTradeTokenConfig.getTradeTokenConfig(tokens[i]);
        }
        for (uint i = 1; i < tokenConfigs.length; i++) {
            AppTradeTokenConfig.TradeTokenConfig memory temp = tokenConfigs[i];
            address tempToken = tokens[i];
            uint j = i;
            while ((j >= 1) && (temp.discount < tokenConfigs[j - 1].discount)) {
                tokenConfigs[j] = tokenConfigs[j - 1];
                tokens[j] = tokens[j - 1];
                j--;
            }
            tokenConfigs[j] = temp;
            tokens[j] = tempToken;
        }
        return tokens;
    }

    /// @dev Returns the token balance for a given token address.
    /// @param self The account storage
    /// @param token The address of the token to get the balance for.
    /// @return The TokenBalance
    function getTokenBalance(Props storage self, address token) public view returns (TokenBalance memory) {
        return self.tokenBalances[token];
    }

    /// @dev Returns the total amount of a given token.
    /// @param self The account storage
    /// @param token The address of the token to get the amount for.
    /// @return The total amount of the specified token.
    function getTokenAmount(Props storage self, address token) public view returns (uint256) {
        return self.tokenBalances[token].amount;
    }

    /// @dev Returns the available amount of a given token, excluding the used amount.
    /// @param self The account storage
    /// @param token The address of the token to get the available amount for.
    /// @return The available amount of the specified token.
    function getAvailableTokenAmount(Props storage self, address token) public view returns (uint256) {
        if (self.tokenBalances[token].amount > self.tokenBalances[token].usedAmount) {
            return self.tokenBalances[token].amount - self.tokenBalances[token].usedAmount;
        }
        return 0;
    }

    /// @dev Returns the liability amount for a given token.
    /// @param self The account storage
    /// @param token The address of the token to get the liability for.
    /// @return The liability amount of the specified token.
    function getLiability(Props storage self, address token) external view returns (uint256) {
        return self.tokenBalances[token].liability;
    }

    /// @dev Checks if there is any liability for any token.
    /// @param self The account storage
    /// @return True if there is any liability, false otherwise.
    function hasLiability(Props storage self) external view returns (bool) {
        address[] memory tokens = self.tokens.values();
        for (uint256 i; i < tokens.length; i++) {
            if (self.tokenBalances[tokens[i]].liability > 0) {
                return true;
            }
        }
        return false;
    }
}
