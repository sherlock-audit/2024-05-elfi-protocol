// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/// @title Market Storage
/// @dev Library for market storage
library Market {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @dev Struct to store market properties
    /// @param symbol The market symbol
    /// @param stakeToken The address of the pool
    /// @param longPosition MarketPosition
    /// @param shortPositionTokens The set of tokens involved in short positions
    /// @param shortPositionMap A mapping from token addresses to MarketPosition
    /// @param fundingFee FundingFee
    struct Props {
        bytes32 symbol;
        address stakeToken;
        MarketPosition longPosition;
        EnumerableSet.AddressSet shortPositionTokens;
        mapping(address => MarketPosition) shortPositionMap;
        FundingFee fundingFee;
    }

    /// @dev Struct to store market position details
    /// @param openInterest The open interest of the market position
    /// @param entryPrice The entry price of the market position
    struct MarketPosition {
        uint256 openInterest;
        uint256 entryPrice;
    }

    /// @dev Struct to store funding fee details
    /// @param longFundingFeePerQty The funding fee per quantity for long positions
    /// @param shortFundingFeePerQty The funding fee per quantity for short positions
    /// @param totalLongFundingFee The total funding fee accrued for long positions
    /// @param totalShortFundingFee The total funding fee accrued for short positions
    /// @param longFundingFeeRate The funding fee rate for long positions
    /// @param shortFundingFeeRate The funding fee rate for short positions
    /// @param lastUpdateTime The last time the funding fee was updated
    struct FundingFee {
        int256 longFundingFeePerQty;
        int256 shortFundingFeePerQty;
        int256 totalLongFundingFee;
        int256 totalShortFundingFee;
        int256 longFundingFeeRate;
        int256 shortFundingFeeRate;
        uint256 lastUpdateTime;
    }

    event MarketFundingFeeUpdateEvent(bytes32 symbol, FundingFee fundingFee);

    function load(bytes32 symbol) public pure returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.Market", symbol));

        assembly {
            self.slot := s
        }
    }

    function addShortToken(Props storage self, address token) external {
        if (!self.shortPositionTokens.contains(token)) {
            self.shortPositionTokens.add(token);
        }
    }

    function emitFundingFeeEvent(Props storage self) external {
        emit MarketFundingFeeUpdateEvent(self.symbol, self.fundingFee);
    }

    function getShortPositionTokens(Props storage self) external view returns (address[] memory) {
        return self.shortPositionTokens.values();
    }

    function getShortPosition(Props storage self, address token) external view returns (MarketPosition memory) {
        return self.shortPositionMap[token];
    }

    function getAllShortPositions(Props storage self) external view returns (MarketPosition[] memory) {
        address[] memory tokens = self.shortPositionTokens.values();
        MarketPosition[] memory shortPositions = new MarketPosition[](tokens.length);
        for (uint256 i; i < tokens.length; i++) {
            shortPositions[i] = self.shortPositionMap[tokens[i]];
        }
        return shortPositions;
    }

    function getLongOpenInterest(Props storage self) external view returns (uint256) {
        return self.longPosition.openInterest;
    }

    function getAllShortOpenInterest(Props storage self) external view returns (uint256) {
        address[] memory tokens = self.shortPositionTokens.values();
        uint256 sum = 0;
        for (uint256 i; i < tokens.length; i++) {
            sum += self.shortPositionMap[tokens[i]].openInterest;
        }
        return sum;
    }
}
