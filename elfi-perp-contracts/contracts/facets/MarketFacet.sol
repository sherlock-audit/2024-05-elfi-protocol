// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IMarket.sol";
import "../process/MarketQueryProcess.sol";
import "../process/ConfigProcess.sol";
import "../storage/CommonData.sol";
import "../storage/UuidCreator.sol";

contract MarketFacet is IMarket {
    function getAllSymbols() external view override returns (SymbolInfo[] memory) {
        bytes32[] memory symbols = CommonData.getAllSymbols();
        SymbolInfo[] memory infos = new SymbolInfo[](symbols.length);
        for (uint256 i; i < symbols.length; i++) {
            infos[i] = _getSingleSymbol(symbols[i]);
        }
        return infos;
    }

    function getSymbol(bytes32 code) external view override returns (SymbolInfo memory params) {
        return _getSingleSymbol(code);
    }

    function getTradeTokenInfo(address token) external view override returns (IMarket.TradeTokenInfo memory) {
        return MarketQueryProcess.getTradeTokenInfo(token);
    }

    function getStakeUsdToken() external view override returns (address) {
        return CommonData.getStakeUsdToken();
    }

    function getMarketInfo(
        bytes32 code,
        OracleProcess.OracleParam[] calldata oracles
    ) external view override returns (MarketInfo memory) {
        return MarketQueryProcess.getMarketInfo(code, oracles);
    }

    function getLastUuid(bytes32 key) external view override returns (uint256) {
        return UuidCreator.getId(key);
    }

    function _getSingleSymbol(bytes32 code) internal view returns (SymbolInfo memory params) {
        Symbol.Props storage props = Symbol.load(code);
        if (props.stakeToken != address(0)) {
            params.code = props.code;
            params.status = props.status;
            params.stakeToken = props.stakeToken;
            params.indexToken = props.indexToken;
            params.baseToken = props.baseToken;
            params.config = ConfigProcess.getSymbolConfig(code);
        }
    }
}
