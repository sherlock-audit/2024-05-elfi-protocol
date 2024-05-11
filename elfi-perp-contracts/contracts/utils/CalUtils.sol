// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/math/SignedMath.sol";
import "@openzeppelin/contracts/utils/math/SignedSafeMath.sol";

library CalUtils {
    using SafeMath for uint256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SignedMath for int256;
    using SignedSafeMath for int256;

    uint256 public constant SMALL_RATE_PRECISION = 10 ** 18;

    uint256 public constant RATE_PRECISION = 100000;

    uint256 public constant PRICE_PRECISION = 10 ** 8;

    uint256 public constant PRICE_TO_WEI = 10 ** 10;

    uint256 public constant USD_PRECISION = 10 ** 18;

    function mul(uint256 a, uint256 b) external pure returns (uint256) {
        return a.mul(b);
    }

    function div(uint256 a, uint256 b) external pure returns (uint256) {
        return a.div(b);
    }

    function mulRate(uint256 value, uint256 rate) external pure returns (uint256) {
        return Math.mulDiv(value, rate, RATE_PRECISION);
    }

    function mulRate(int256 value, int256 rate) external pure returns (int256) {
        return value.mul(rate).div(RATE_PRECISION.toInt256());
    }

    function divRate(uint256 value, uint256 rate) external pure returns (uint256) {
        return Math.mulDiv(value, RATE_PRECISION, rate);
    }

    function divToPrecision(uint256 value1, uint256 value2, uint256 precision) external pure returns (uint256) {
        return Math.mulDiv(value1, precision, value2);
    }

    function mulDiv(uint256 value1, uint256 value2, uint256 value3) external pure returns (uint256) {
        return Math.mulDiv(value1, value2, value3);
    }

    function divToIntPrecision(int256 value1, int256 value2, int256 precision) external pure returns (int256) {
        return value1.mul(precision).div(value2);
    }

    function mulSmallRate(uint256 value, uint256 rate) external pure returns (uint256) {
        return Math.mulDiv(value, rate, SMALL_RATE_PRECISION);
    }

    function mulIntSmallRate(int256 value, int256 rate) external pure returns (int256) {
        return value.mul(rate).div(SMALL_RATE_PRECISION.toInt256());
    }

    function divSmallRate(uint256 value, uint256 rate) external pure returns (uint256) {
        return Math.mulDiv(value, SMALL_RATE_PRECISION, rate);
    }

    function quietAdd(uint256 value1, int256 value2) external pure returns (uint256) {
        int256 result = value1.toInt256() + value2;
        return result <= 0 ? 0 : result.toUint256();
    }

    function tokenToUsd(uint256 tokenAmount, uint8 tokenDecimals, uint256 tokenPrice) external pure returns (uint256) {
        return tokenAmount.mul(tokenPrice).mul(PRICE_TO_WEI).div(10 ** tokenDecimals);
    }

    function tokenToUsdInt(int256 tokenAmount, uint8 tokenDecimals, int256 tokenPrice) external pure returns (int256) {
        return tokenAmount.mul(tokenPrice).mul(PRICE_TO_WEI.toInt256()).div((10 ** tokenDecimals).toInt256());
    }

    function usdToToken(
        uint256 tokenUsdAmount,
        uint8 tokenDecimals,
        uint256 tokenPrice
    ) external pure returns (uint256) {
        return Math.mulDiv(tokenUsdAmount, 10 ** tokenDecimals, tokenPrice.mul(PRICE_TO_WEI));
    }

    function usdToTokenInt(
        int256 tokenUsdAmount,
        uint8 tokenDecimals,
        int256 tokenPrice
    ) external pure returns (int256) {
        return tokenUsdAmount.mul((10 ** tokenDecimals).toInt256()).div(tokenPrice.mul(PRICE_TO_WEI.toInt256()));
    }

    function tokenToToken(
        uint256 originTokenAmount,
        uint8 originTokenDecimals,
        uint8 targetTokenDecimals,
        uint256 tokenToTokenPrice
    ) external pure returns (uint256) {
        if (targetTokenDecimals >= originTokenDecimals) {
            return
                originTokenAmount.mul(tokenToTokenPrice).mul(10 ** (targetTokenDecimals - originTokenDecimals)).div(
                    PRICE_PRECISION
                );
        } else {
            return
                originTokenAmount.mul(tokenToTokenPrice).div(PRICE_PRECISION).div(
                    10 ** (originTokenDecimals - targetTokenDecimals)
                );
        }
    }

    function tokenToToken(
        uint256 originTokenAmount,
        uint8 originTokenDecimals,
        uint8 targetTokenDecimals,
        uint256 originTokenPrice,
        uint256 targetTokenPrice
    ) external pure returns (uint256) {
        if (targetTokenDecimals >= originTokenDecimals) {
            return
                originTokenAmount.mul(originTokenPrice).mul(10 ** (targetTokenDecimals - originTokenDecimals)).div(
                    targetTokenPrice
                );
        } else {
            return
                originTokenAmount.mul(originTokenPrice).div(targetTokenPrice).div(
                    10 ** (originTokenDecimals - targetTokenDecimals)
                );
        }
    }

    function decimalsToDecimals(
        uint256 value,
        uint8 originDecimals,
        uint8 targetDecimals
    ) external pure returns (uint256) {
        return Math.mulDiv(value, 10 ** targetDecimals, 10 ** originDecimals);
    }

    function computeAvgEntryPrice(
        uint256 qty,
        uint256 entryPrice,
        uint256 increaseQty,
        uint256 tokenPrice,
        uint256 tickSize,
        bool isUp
    ) external pure returns (uint256) {
        uint256 originEntryPrice = (qty.mul(entryPrice).add(increaseQty.mul(tokenPrice))).div(qty + increaseQty);
        return formatToTickSize(originEntryPrice, tickSize, isUp);
    }

    function formatToTickSize(uint256 value, uint256 tickSize, bool roundUp) public pure returns (uint256) {
        uint256 mod = value % tickSize;
        if (mod == 0) {
            return value;
        } else {
            return (value.div(tickSize).add((roundUp ? 1 : 0))).mul(tickSize);
        }
    }

    function diff(uint256 value1, uint256 value2) external pure returns (uint256) {
        return value1 > value2 ? value1 - value2 : value2 - value1;
    }
}
