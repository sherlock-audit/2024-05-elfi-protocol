// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/MarketFactoryProcess.sol";
import "../process/ConfigProcess.sol";
import "../interfaces/IConfig.sol";

interface IMarketManager {
    function createMarket(MarketFactoryProcess.CreateMarketParams calldata params) external;

    function createStakeUsdPool(string calldata stakeTokenName, uint8 decimals) external returns (address);
}
