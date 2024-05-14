// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./AppStorage.sol";

library Referral {
    using AppStorage for AppStorage.Props;

    // -- Referral keys --
    bytes32 public constant REFERRAL_CODE = keccak256(abi.encode("REFERRAL_CODE"));

    struct Props {
        address account;
        bytes32 code;
        bytes32 referralCode;
    }

    event ReferralUpdateEvent(address account, bytes32 code, bytes32 referralCode);

    function load(address account) public pure returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.Referral", account));

        assembly {
            self.slot := s
        }
    }

    function loadOrCreate(address account) public returns (Props storage self) {
        bytes32 s = keccak256(abi.encode("xyz.elfi.storage.Referral", account));

        assembly {
            self.slot := s
        }

        if (self.account == address(0)) {
            self.account = account;
        }
    }

    function createCodeIfNotExists(Props storage self, bytes32 code) external {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = keccak256(abi.encode(AppStorage.REFERRAL, REFERRAL_CODE));
        if (app.containsBytes32(key, code)) {
            return;
        }
        if (self.code == bytes32(0)) {
            self.code = code;
            app.addBytes32(key, code);
            app.setAddressValue(keccak256(abi.encode(key, code)), self.account);
            emit ReferralUpdateEvent(self.account, self.code, self.referralCode);
        }
    }

    function bindReferralCodeIfNotExists(Props storage self, bytes32 referralCode) external {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = keccak256(abi.encode(AppStorage.REFERRAL, REFERRAL_CODE));
        if (app.containsBytes32(key, referralCode)) {
            return;
        }
        if (self.referralCode == bytes32(0)) {
            self.referralCode = referralCode;
            emit ReferralUpdateEvent(self.account, self.code, self.referralCode);
        }
    }

    function isCodeExists(bytes32 code) external view returns (bool) {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = keccak256(abi.encode(AppStorage.REFERRAL, REFERRAL_CODE));
        return app.containsBytes32(key, code);
    }

    function getCodeAccount(bytes32 code) external view returns (address) {
        AppStorage.Props storage app = AppStorage.load();
        bytes32 key = keccak256(abi.encode(AppStorage.REFERRAL, REFERRAL_CODE));
        return app.getAddressValue(keccak256(abi.encode(key, code)));
    }
}
