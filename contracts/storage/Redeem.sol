// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title Redeem Storage
/// @dev Library for redeem storage
library Redeem {
    
    bytes32 constant REDEEM_KEY = keccak256(abi.encode("xyz.elfi.storage.Redeem"));

    /// @dev Struct to store redeem requests
    /// @param requests A mapping from request IDs to Redeem.Request
    struct Props {
        mapping(uint256 => Request) requests;
    }

    /// @dev Struct to store details of a redeem request
    /// @param account The address of the account
    /// @param receiver The address of the receiver getting the redeemed token
    /// @param stakeToken The address of the pool
    /// @param redeemToken The address of the token being redeemed
    /// @param unStakeAmount The amount of stake token to be unstaked
    /// @param minRedeemAmount The minimum amount of redeem token expected
    /// @param executionFee The execution fee for the keeper
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
