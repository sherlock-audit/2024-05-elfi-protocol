// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "../storage/Referral.sol";

interface IReferral {
    function isCodeExists(bytes32 code) external view returns (bool);

    function getAccountReferral(address account) external pure returns (Referral.Props memory);

}
