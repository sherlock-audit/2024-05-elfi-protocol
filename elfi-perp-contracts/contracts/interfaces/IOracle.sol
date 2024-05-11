// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/OracleProcess.sol";

interface IOracle {
    
  function getLatestUsdPrice(address token, bool min) external view returns (int256);

  function setOraclePrices(OracleProcess.OracleParam[] calldata params) external;
}
