// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../storage/OracleFeed.sol";
import "../storage/OraclePrice.sol";
import "../utils/AddressUtils.sol";
import "../utils/Errors.sol";

library OracleProcess {
    using OraclePrice for OraclePrice.Props;
    using SafeCast for int256;

    struct OracleParam {
        address token;
        address targetToken;
        int256 minPrice;
        int256 maxPrice;
    }

    function setOraclePrice(OracleParam[] calldata params) external {
        OraclePrice.Props storage oracle = OraclePrice.load();
        for (uint256 i; i < params.length; i++) {
            if (params[i].targetToken == address(0)) {
                oracle.setPrice(params[i].token, OraclePrice.Data(params[i].minPrice, params[i].maxPrice));
            } else {
                oracle.setPrice(
                    params[i].token,
                    params[i].targetToken,
                    OraclePrice.Data(params[i].minPrice, params[i].maxPrice)
                );
            }
        }
    }

    function getIntOraclePrices(OracleParam[] memory params, address token, bool isMin) external view returns (int256) {
        for (uint256 i; i < params.length; i++) {
            if (params[i].token == token) {
                return isMin ? params[i].minPrice : params[i].maxPrice;
            }
        }
        return getLatestUsdPrice(token, isMin);
    }

    function getIntOraclePrices(
        OracleParam[] memory params,
        address token,
        address targetToken,
        bool isMin
    ) external view returns (int256) {
        for (uint256 i; i < params.length; i++) {
            if (params[i].token == token && params[i].targetToken == targetToken) {
                return isMin ? params[i].minPrice : params[i].maxPrice;
            }
        }
        return getLatestUsdPrice(token, targetToken, isMin);
    }

    function getOraclePrices(OracleParam[] memory params, address token, bool isMin) external view returns (uint256) {
        for (uint256 i; i < params.length; i++) {
            if (params[i].token == token) {
                return isMin ? uint256(params[i].minPrice) : uint256(params[i].maxPrice);
            }
        }
        return getLatestUsdUintPrice(token, isMin);
    }

    function getOraclePrices(
        OracleParam[] memory params,
        address token,
        address targetToken,
        bool isMin
    ) external view returns (uint256) {
        for (uint256 i; i < params.length; i++) {
            if (params[i].token == token) {
                return isMin ? uint256(params[i].minPrice) : uint256(params[i].maxPrice);
            }
        }
        return getLatestUsdUintPrice(token, targetToken, isMin);
    }

    function clearOraclePrice() external {
        OraclePrice.load().clearAllPrice();
    }

    function getLatestUsdUintPrice(address token, address targetToken, bool min) public view returns (uint256) {
        return getLatestUsdPrice(token, targetToken, min).toUint256();
    }

    function getLatestUsdPrice(address token, address targetToken, bool min) public view returns (int256) {
        OraclePrice.Props storage oracle = OraclePrice.load();
        OraclePrice.Data memory tokenPrice = oracle.getPrice(token, targetToken);
        if (tokenPrice.min == 0 || tokenPrice.max == 0) {
            revert Errors.PriceIsZero();
        }
        return min ? tokenPrice.min : tokenPrice.max;
    }

    function getLatestUsdPrice(address token, bool min) public view returns (int256) {
        OraclePrice.Data memory data = _getLatestUsdPriceWithOracle(token);
        return min ? data.min : data.max;
    }

    function getLatestUsdUintPrice(address token, bool min) public view returns (uint256) {
        OraclePrice.Data memory data = _getLatestUsdPriceWithOracle(token);
        return min ? uint256(data.min) : uint256(data.max);
    }

    function getLatestUsdPrice(address token) public view returns (OraclePrice.Data memory) {
        return _getLatestUsdPriceWithOracle(token);
    }

    function getLatestUsdUintPrice(address token) public view returns (uint256 min, uint256 max) {
        OraclePrice.Data memory data = _getLatestUsdPriceWithOracle(token);
        return (uint256(data.min), uint256(data.max));
    }

    function _getLatestUsdPriceWithOracle(address token) internal view returns (OraclePrice.Data memory) {
        OraclePrice.Props storage oracle = OraclePrice.load();
        OraclePrice.Data memory tokenPrice = oracle.getPrice(token);
        if (tokenPrice.min == 0 || tokenPrice.max == 0) {
            revert Errors.PriceIsZero();
        }
        return tokenPrice;
    }
}
