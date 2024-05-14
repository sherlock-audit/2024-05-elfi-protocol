// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


library Withdraw {
    bytes32 constant WITHDRAW_KEY = keccak256(abi.encode("xyz.elfi.storage.Withdraw"));

    struct Props {
        mapping(uint256 => Request) requests;
    }

    struct Request {
        address account;
        address token;
        uint256 amount;
    }

    function load() public pure returns (Props storage self) {
        bytes32 s = WITHDRAW_KEY;
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
