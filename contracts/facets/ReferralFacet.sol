// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../interfaces/IReferral.sol";

contract ReferralFacet is IReferral {

    using Referral for Referral.Props;

    function isCodeExists(bytes32 code) external view override returns (bool) {
        return Referral.isCodeExists(code);
    }

    function getAccountReferral(address account) external pure override returns (Referral.Props memory) {
        return Referral.load(account);
    }

}
