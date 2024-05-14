// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


library ClaimRewards {
    bytes32 constant KEY = keccak256(abi.encode("xyz.elfi.storage.ClaimRewards"));

    struct Props {
        mapping(uint256 => Request) requests;
    }

    struct Request {
        address account;
        address claimUsdToken;
        uint256 executionFee;
    }

    function load() public pure returns (Props storage self) {
        bytes32 s = KEY;
        assembly {
            self.slot := s
        }
    }

    function create(uint256 requestId) external view returns (Request storage) {
        Props storage self = load();
        return self.requests[requestId];
    }

    function get(uint256 requestId) external view returns (Request memory) {
        Props storage self = load();
        return self.requests[requestId];
    }

    function remove(uint256 requestId) external {
        Props storage self = load();
        delete self.requests[requestId];
    }
}
