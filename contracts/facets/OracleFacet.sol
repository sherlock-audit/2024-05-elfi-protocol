// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IOracle.sol";

contract OracleFacet is IOracle {
    function getLatestUsdPrice(address token, bool min) external view returns (int256) {
        return OracleProcess.getLatestUsdPrice(token, min);
    }

    function setOraclePrices(OracleProcess.OracleParam[] calldata params) external {
        OracleProcess.setOraclePrice(params);
    }
}
