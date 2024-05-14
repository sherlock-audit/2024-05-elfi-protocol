// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

library Market {
    using EnumerableSet for EnumerableSet.AddressSet;

    struct Props {
        bytes32 symbol;
        address stakeToken;
        MarketPosition longPosition;
        EnumerableSet.AddressSet shortPositionTokens;
        mapping(address => MarketPosition) shortPositionMap;
        FundingFee fundingFee;
    }

    struct MarketPosition {
        uint256 openInterest;
        uint256 entryPrice;
    }

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
