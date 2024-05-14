// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../process/ConfigProcess.sol";
import "../storage/RoleAccessControl.sol";

contract ConfigFacet {
    function getConfig() external view returns (IConfig.CommonConfigParams memory config) {
        return ConfigProcess.getConfig();
    }

    function getPoolConfig(address stakeToken) public view returns (AppPoolConfig.LpPoolConfig memory) {
        return ConfigProcess.getPoolConfig(stakeToken);
    }

    function getUsdPoolConfig() public view returns (AppPoolConfig.UsdPoolConfig memory) {
        return ConfigProcess.getUsdPoolConfig();
    }

    function getSymbolConfig(bytes32 code) public view returns (AppConfig.SymbolConfig memory) {
        return ConfigProcess.getSymbolConfig(code);
    }

    function setConfig(IConfig.CommonConfigParams calldata params) external {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_CONFIG);
        ConfigProcess.setConfig(params);
    }

    function setUniswapRouter(address router) external {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_CONFIG);
        ConfigProcess.setUniswapRouter(router);
    }

    function setPoolConfig(IConfig.LpPoolConfigParams calldata params) external {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_CONFIG);
        ConfigProcess.setPoolConfig(params);
    }

    function setUsdPoolConfig(IConfig.UsdPoolConfigParams calldata params) external {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_CONFIG);
        ConfigProcess.setUsdPoolConfig(params);
    }

    function setSymbolConfig(IConfig.SymbolConfigParams calldata params) external {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_CONFIG);
        ConfigProcess.setSymbolConfig(params);
    }

    function setVaultConfig(IConfig.VaultConfigParams calldata params) external {
        RoleAccessControl.checkRole(RoleAccessControl.ROLE_CONFIG);
        ConfigProcess.setVaultConfig(params);
    }
}
