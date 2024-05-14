// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/MarketQueryProcess.sol";
import "../interfaces/IConfig.sol";
import "../process/OracleProcess.sol";
import "../storage/Symbol.sol";
import "../storage/Market.sol";

interface IMarket {
    struct SymbolInfo {
        bytes32 code;
        Symbol.Status status;
        address stakeToken;
        address indexToken;
        address baseToken;
        AppConfig.SymbolConfig config;
    }

    struct MarketInfo {
        Symbol.Props symbolInfo;
        uint256 longPositionInterest;
        uint256 longPositionEntryPrice;
        uint256 totalShortPositionInterest;
        Market.MarketPosition[] shortPositions;
        uint256 availableLiquidity;
        Market.FundingFee fundingFee;
    }

    struct TradeTokenInfo {
        uint256 tradeTokenCollateral;
        uint256 tradeTokenLiability;
    }

    function getAllSymbols() external view returns (SymbolInfo[] memory);

    function getSymbol(bytes32 code) external view returns (SymbolInfo memory);

    function getStakeUsdToken() external view returns (address);

    function getTradeTokenInfo(address token) external view returns (TradeTokenInfo memory);

    function getMarketInfo(
        bytes32 code,
        OracleProcess.OracleParam[] calldata oracles
    ) external view returns (MarketInfo memory);

    function getLastUuid(bytes32 key) external view returns (uint256);
}
