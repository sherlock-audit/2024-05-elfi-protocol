// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../utils/Errors.sol";

library Position {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeCast for uint256;

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

    event PositionUpdateEvent(
        uint256 requestId,
        bytes32 positionKey,
        PositionUpdateFrom from,
        Props position,
        SettleData settleData
    );

    function load(
        address account,
        bytes32 symbol,
        address marginToken,
        bool isCrossMargin
    ) public pure returns (Props storage position) {
        return load(getPositionKey(account, symbol, marginToken, isCrossMargin));
    }

    function load(bytes32 key) public pure returns (Props storage self) {
        assembly {
            self.slot := key
        }
    }

    function getPositionKey(
        address account,
        bytes32 symbol,
        address marginToken,
        bool isCrossMargin
    ) public pure returns (bytes32) {
        return keccak256(abi.encode("xyz.elfi.storage.Position", account, symbol, marginToken, isCrossMargin));
    }

    function hasPosition(Props storage self) external view returns (bool) {
        return self.qty > 0;
    }

    function checkExists(Props storage self) external view {
        if (self.qty == 0) {
            revert Errors.PositionNotExists();
        }
    }

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
