// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./AppStorage.sol";

library AppVaultConfig {
    using AppStorage for AppStorage.Props;

    // -- vault config keys --
    bytes32 public constant TRADE_VAULT = keccak256(abi.encode("TRADE_VAULT"));
    bytes32 public constant LP_VAULT = keccak256(abi.encode("LP_VAULT"));
    bytes32 public constant PORTFOLIO_VAULT = keccak256(abi.encode("PORTFOLIO_VAULT"));

    function getTradeVault() public view returns (address) {
        AppStorage.Props storage app = AppStorage.load();
        return app.getAddressValue(keccak256(abi.encode(AppStorage.VAULT_CONFIG, TRADE_VAULT)));
    }

    function setTradeVault(address vault) internal {
        AppStorage.Props storage app = AppStorage.load();
        app.setAddressValue(keccak256(abi.encode(AppStorage.VAULT_CONFIG, TRADE_VAULT)), vault);
    }

    function getLpVault() public view returns (address) {
        AppStorage.Props storage app = AppStorage.load();
        return app.getAddressValue(keccak256(abi.encode(AppStorage.VAULT_CONFIG, LP_VAULT)));
    }

    function setLpVault(address vault) internal {
        AppStorage.Props storage app = AppStorage.load();
        app.setAddressValue(keccak256(abi.encode(AppStorage.VAULT_CONFIG, LP_VAULT)), vault);
    }

    function getPortfolioVault() public view returns (address) {
        AppStorage.Props storage app = AppStorage.load();
        return app.getAddressValue(keccak256(abi.encode(AppStorage.VAULT_CONFIG, PORTFOLIO_VAULT)));
    }

    function setPortfolioVault(address vault) internal {
        AppStorage.Props storage app = AppStorage.load();
        app.setAddressValue(keccak256(abi.encode(AppStorage.VAULT_CONFIG, PORTFOLIO_VAULT)), vault);
    }
}
