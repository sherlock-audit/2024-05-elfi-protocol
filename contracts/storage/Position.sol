// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../utils/Errors.sol";

/// @title Position Storage
/// @dev Library for position storage 
library Position {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCast for uint256;

    /// @dev Position.Props struct used for storing position information
    ///
    /// @param key the unique key for position
    /// @param symbol the market to which the position belongs
    /// @param isLong  whether the direction of the position is long 
    /// @param isCrossMargin whether it is a cross-margin position
    /// @param account the address to whom the position belongs
    /// @param marginToken the address of margin token
    /// @param indexToken the address of market index token
    /// @param qty the position‘s size in USD
    /// @param entryPrice average entry price
    /// @param leverage the leverage of the position
    /// @param initialMargin the position's initial margin in tokens
    /// @param initialMarginInUsd the position's initial margin in USD
    /// @param initialMarginInUsdFromBalance the position's initial margin from the assets actually held by the account in USD
    /// @param holdPoolAmount the amount in tokens of the token hold in the pool.
    /// @param positionFee the position‘s fee
    /// @param realizedPnl the position realized profit and loss
    /// @param lastUpdateTime the latest update time of the position
    struct Props {
        bytes32 key;
        bytes32 symbol;
        bool isLong;
        bool isCrossMargin;
        address account;
        address marginToken;
        address indexToken;
        uint256 qty;
        uint256 entryPrice;
        uint256 leverage;
        uint256 initialMargin;
        uint256 initialMarginInUsd;
        uint256 initialMarginInUsdFromBalance;
        uint256 holdPoolAmount;
        PositionFee positionFee;
        int256 realizedPnl;
        uint256 lastUpdateTime;
    }

    /// @dev PositionFee struct used for storing position fees
    ///
    /// @param closeFeeInUsd closing fee in USD for fully closing the position
    /// @param openBorrowingFeePerToken the position's open borrowing fee per token
    /// @param realizedBorrowingFee the position's settled borrowing fee in tokens
    /// @param realizedBorrowingFeeInUsd the position's settled borrowing fee in USD
    /// @param openFundingFeePerQty the position's open funding fee per qty
    /// @param realizedFundingFee the position's settled funding fee in tokens
    /// @param realizedFundingFeeInUsd the position's settled funding fee in USD
    struct PositionFee {
        uint256 closeFeeInUsd;
        uint256 openBorrowingFeePerToken;
        uint256 realizedBorrowingFee;
        uint256 realizedBorrowingFeeInUsd;
        int256 openFundingFeePerQty;
        int256 realizedFundingFee;
        int256 realizedFundingFeeInUsd;
    }

    enum PositionUpdateFrom {
        NONE,
        ORDER_INCREASE,
        ORDER_DECREASE,
        ADD_MARGIN,
        DECREASE_MARGIN,
        INCREASE_LEVERAGE,
        DECREASE_LEVERAGE,
        LIQUIDATION,
        DEPOSIT
    }

    /// @dev Struct representing the data settled during position update
    ///
    /// @param executePrice the execution price of the position update
    /// @param openFee the opening fee for the position
    /// @param marginTokenPrice the price of the margin token
    /// @param settledMargin the settled margin amount
    /// @param settledBorrowingFee the settled borrowing fee
    /// @param settledBorrowingFeeInUsd the settled borrowing fee in USD
    /// @param settledFundingFee the settled funding fee
    /// @param settledFundingFeeInUsd the settled funding fee in USD
    /// @param unHoldPoolAmount the amount of token released from the pool
    /// @param closeFee the closing fee
    /// @param closeFeeInUsd the closing fee in USD
    /// @param realizedPnl the realized profit and loss
    /// @param poolPnlToken the pool profit and loss in tokens
    struct SettleData {
        uint256 executePrice;
        uint256 openFee;
        uint256 marginTokenPrice;
        int256 settledMargin;
        uint256 settledBorrowingFee;
        uint256 settledBorrowingFeeInUsd;
        int256 settledFundingFee;
        int256 settledFundingFeeInUsd;
        uint256 unHoldPoolAmount;
        uint256 closeFee;
        uint256 closeFeeInUsd;
        int256 realizedPnl;
        int256 poolPnlToken;
    }

    /// @dev Event emitted when a position is updated
    /// @param requestId the ID of the request
    /// @param positionKey the unique key of the position
    /// @param from the source of the position update
    /// @param position Position.Props
    /// @param settleData Position.SettleData
    event PositionUpdateEvent(
        uint256 requestId,
        bytes32 positionKey,
        PositionUpdateFrom from,
        Props position,
        SettleData settleData
    );

    /// @dev Loads the position properties from storage based on account, symbol, margin token, and cross-margin flag
    /// @param account the address of the account
    /// @param symbol the symbol of the position
    /// @param marginToken the address of the margin token
    /// @param isCrossMargin whether the position is cross-margin
    /// @return position Position.Props
    function load(
        address account,
        bytes32 symbol,
        address marginToken,
        bool isCrossMargin
    ) public pure returns (Props storage position) {
        return load(getPositionKey(account, symbol, marginToken, isCrossMargin));
    }

    /// @dev Loads the position properties from storage based on the position key
    /// @param key the unique key of the position
    /// @return self Position.Props
    function load(bytes32 key) public pure returns (Props storage self) {
        assembly {
            self.slot := key
        }
    }

    /// @dev Generates the unique key for a position based on account, symbol, margin token, and cross-margin flag
    /// @param account the address of the account
    /// @param symbol the symbol of the position
    /// @param marginToken the address of the margin token
    /// @param isCrossMargin whether the position is cross-margin
    /// @return the unique key for the position
    function getPositionKey(
        address account,
        bytes32 symbol,
        address marginToken,
        bool isCrossMargin
    ) public pure returns (bytes32) {
        return keccak256(abi.encode("xyz.elfi.storage.Position", account, symbol, marginToken, isCrossMargin));
    }

    /// @dev Checks if the position exists
    /// @param self the position properties
    /// @return true if the position exists, false otherwise
    function hasPosition(Props storage self) external view returns (bool) {
        return self.qty > 0;
    }

    /// @dev Checks if the position exists and reverts with an error if it does not
    /// @param self the position properties
    function checkExists(Props storage self) external view {
        if (self.qty == 0) {
            revert Errors.PositionNotExists();
        }
    }

    /// @dev Resets the position properties to their default values
    /// @param self Position.Props
    function reset(Props storage self) external {
        self.qty = 0;
        self.entryPrice = 0;
        self.leverage = 0;
        self.initialMargin = 0;
        self.initialMarginInUsd = 0;
        self.initialMarginInUsdFromBalance = 0;
        self.holdPoolAmount = 0;
        self.positionFee.closeFeeInUsd = 0;
        self.realizedPnl = 0;
        self.positionFee.closeFeeInUsd = 0;
        self.positionFee.openBorrowingFeePerToken = 0;
        self.positionFee.realizedBorrowingFee = 0;
        self.positionFee.realizedBorrowingFeeInUsd = 0;
        self.positionFee.openFundingFeePerQty = 0;
        self.positionFee.realizedFundingFee = 0;
        self.positionFee.realizedFundingFeeInUsd = 0;
    }

    /// @dev Emits a position update event with the given parameters
    /// @param self Position.Props
    /// @param requestId the ID of the request
    /// @param from the source of the position update
    /// @param executePrice the execution price of the position update
    function emitPositionUpdateEvent(
        Props storage self,
        uint256 requestId,
        PositionUpdateFrom from,
        uint256 executePrice
    ) external {
        emit PositionUpdateEvent(
            requestId,
            getPositionKey(self.account, self.symbol, self.marginToken, self.isCrossMargin),
            from,
            self,
            SettleData(executePrice, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        );
    }

    /// @dev Emits a position update event with the given settle data
    /// @param self Position.Props
    /// @param requestId the ID of the request
    /// @param from the source of the position update
    /// @param settleData Position.SettledData
    function emitPositionUpdateEvent(
        Props storage self,
        uint256 requestId,
        PositionUpdateFrom from,
        SettleData memory settleData
    ) external {
        emit PositionUpdateEvent(
            requestId,
            getPositionKey(self.account, self.symbol, self.marginToken, self.isCrossMargin),
            from,
            self,
            settleData
        );
    }

    /// @dev Emits an open position update event with the given parameters
    /// @param self Position.Props
    /// @param requestId the ID of the request
    /// @param from the source of the position update
    /// @param executePrice the execution price of the position update
    /// @param openFee the opening fee for the position
    function emitOpenPositionUpdateEvent(
        Props storage self,
        uint256 requestId,
        PositionUpdateFrom from,
        uint256 executePrice,
        uint256 openFee
    ) external {
        emit PositionUpdateEvent(
            requestId,
            getPositionKey(self.account, self.symbol, self.marginToken, self.isCrossMargin),
            from,
            self,
            SettleData(executePrice, openFee, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        );
    }
}
