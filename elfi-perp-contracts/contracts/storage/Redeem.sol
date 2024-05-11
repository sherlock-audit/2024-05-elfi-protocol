// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


library Redeem {
    
    bytes32 constant REDEEM_KEY = keccak256(abi.encode("xyz.elfi.storage.Redeem"));

    struct Props {
        mapping(uint256 => Request) requests;
    }

    struct Request {
        address account;
        address receiver;
        address stakeToken;
        address redeemToken;
        uint256 unStakeAmount;
        uint256 minRedeemAmount;
        uint256 executionFee;
    }

    function load() public pure returns (Props storage self) {
        bytes32 s = REDEEM_KEY;
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
