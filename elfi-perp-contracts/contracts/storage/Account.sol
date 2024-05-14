// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./CommonData.sol";
import "./AppTradeTokenConfig.sol";
import "../utils/Errors.sol";

library Account {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.UintSet;
    using CommonData for CommonData.Props;

    struct Props {
        address owner;
        uint256 orderHoldInUsd;
        EnumerableSet.AddressSet tokens;
        mapping(address => Account.TokenBalance) tokenBalances;
        EnumerableSet.Bytes32Set positions;
        EnumerableSet.UintSet orders;
    }

    struct TokenBalance {
        uint256 amount;
        uint256 usedAmount;
        uint256 interest;
        uint256 liability;
    }

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

    function load(address owner) public pure returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.Account", owner));
        assembly {
            self.slot := s
        }
    }

    function loadOrCreate(address owner) public returns (Props storage) {
        Props storage self = load(owner);
        if (self.owner == address(0)) {
            self.owner = owner;
        }
        return self;
    }

    function addOrderHoldInUsd(Props storage self, uint256 holdInUsd) external {
        uint256 preOrderHoldInUsd = self.orderHoldInUsd;
        self.orderHoldInUsd += holdInUsd;
        emit AccountOrderHoldInUsdUpdateEvent(self.owner, preOrderHoldInUsd, self.orderHoldInUsd);
    }

    function subOrderHoldInUsd(Props storage self, uint256 holdInUsd) external {
        require(self.orderHoldInUsd >= holdInUsd, "orderHoldInUsd is smaller than holdInUsd");
        uint256 preOrderHoldInUsd = self.orderHoldInUsd;
        self.orderHoldInUsd -= holdInUsd;
        emit AccountOrderHoldInUsdUpdateEvent(self.owner, preOrderHoldInUsd, self.orderHoldInUsd);
    }

    function addToken(Props storage self, address token, uint256 amount) external {
        addToken(self, token, amount, UpdateSource.DEFAULT);
    }

    function addToken(Props storage self, address token, uint256 amount, UpdateSource source) public {
        if (!self.tokens.contains(token)) {
            self.tokens.add(token);
        }
        TokenBalance storage balance = self.tokenBalances[token];
        TokenBalance memory preBalance = balance;
        balance.amount += amount;
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, balance, source);
    }

    function subToken(Props storage self, address token, uint256 amount) external {
        subToken(self, token, amount, UpdateSource.DEFAULT);
    }

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

    function subTokenIgnoreUsedAmount(Props storage self, address token, uint256 amount) external {
        subTokenIgnoreUsedAmount(self, token, amount, UpdateSource.DEFAULT);
    }

    function subTokenIgnoreUsedAmount(Props storage self, address token, uint256 amount, UpdateSource source) public {
        require(self.tokens.contains(token), "token not exists!");
        require(self.tokenBalances[token].amount >= amount, "token amount not enough!");
        TokenBalance memory preBalance = self.tokenBalances[token];
        self.tokenBalances[token].amount -= amount;
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, self.tokenBalances[token], source);
    }

    function subTokenWithLiability(
        Props storage self,
        address token,
        uint256 amount
    ) external returns (uint256 liability) {
        return subTokenWithLiability(self, token, amount, UpdateSource.DEFAULT);
    }

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

    function useToken(Props storage self, address token, uint256 amount) external returns (uint256 useFromBalance) {
        return useToken(self, token, amount, false, UpdateSource.DEFAULT);
    }

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

    function unUseToken(Props storage self, address token, uint256 amount) public {
        unUseToken(self, token, amount, UpdateSource.DEFAULT);
    }

    function unUseToken(Props storage self, address token, uint256 amount, UpdateSource source) public {
        require(self.tokens.contains(token), "token not exists!");
        require(self.tokenBalances[token].usedAmount >= amount, "unUse overflow!");
        TokenBalance memory preBalance = self.tokenBalances[token];
        self.tokenBalances[token].usedAmount -= amount;
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, self.tokenBalances[token], source);
    }

    function repayLiability(Props storage self, address token) external returns (uint256 repayAmount) {
        return repayLiability(self, token, UpdateSource.DEFAULT);
    }

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

    function clearLiability(Props storage self, address token) external {
        clearLiability(self, token, UpdateSource.DEFAULT);
    }

    function clearLiability(Props storage self, address token, UpdateSource source) public {
        TokenBalance storage balance = self.tokenBalances[token];
        TokenBalance memory preBalance = balance;
        CommonData.load().subTokenLiability(token, balance.liability);
        balance.usedAmount -= balance.liability;
        balance.liability = 0;
        emit AccountTokenUpdateEvent(self.owner, token, preBalance, balance, source);
    }

    function addPosition(Props storage self, bytes32 position) external {
        if (!self.positions.contains(position)) {
            self.positions.add(position);
        }
    }

    function delPosition(Props storage self, bytes32 position) external {
        self.positions.remove(position);
    }

    function checkExists(Props storage self) external view {
        if (self.owner == address(0)) {
            revert Errors.AccountNotExist();
        }
    }

    function isExists(Props storage self) external view returns (bool) {
        return self.owner != address(0);
    }

    function getAllPosition(Props storage self) external view returns (bytes32[] memory) {
        return self.positions.values();
    }

    function hasPosition(Props storage self) external view returns (bool) {
        return self.positions.length() > 0;
    }

    function hasPosition(Props storage self, bytes32 key) external view returns (bool) {
        return self.positions.contains(key);
    }

    function getAllOrders(Props storage self) external view returns (uint256[] memory) {
        return self.orders.values();
    }

    function hasOrder(Props storage self) external view returns (bool) {
        return self.orders.length() > 0;
    }

    function hasOtherOrder(Props storage self, uint256 orderId) external view returns (bool) {
        uint256[] memory orderIds = self.orders.values();
        for (uint256 i; i < orderIds.length; i++) {
            if (orderIds[i] != orderId) {
                return true;
            }
        }
        return false;
    }

    function addOrder(Props storage self, uint256 orderId) external {
        if (!self.orders.contains(orderId)) {
            self.orders.add(orderId);
        }
    }

    function delOrder(Props storage self, uint256 orderId) external {
        self.orders.remove(orderId);
    }

    function getOrders(Props storage self) external view returns (uint256[] memory) {
        return self.orders.values();
    }

    function getTokens(Props storage self) public view returns (address[] memory) {
        return self.tokens.values();
    }

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

    function getTokenBalance(Props storage self, address token) public view returns (TokenBalance memory) {
        return self.tokenBalances[token];
    }

    function getTokenAmount(Props storage self, address token) public view returns (uint256) {
        return self.tokenBalances[token].amount;
    }

    function getAvailableTokenAmount(Props storage self, address token) public view returns (uint256) {
        if (self.tokenBalances[token].amount > self.tokenBalances[token].usedAmount) {
            return self.tokenBalances[token].amount - self.tokenBalances[token].usedAmount;
        }
        return 0;
    }

    function getLiability(Props storage self, address token) external view returns (uint256) {
        return self.tokenBalances[token].liability;
    }

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
