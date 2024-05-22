// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title Update Position Margin Storage
/// @dev Library for update position margin requests storage 
library UpdatePositionMargin {
    bytes32 constant KEY = keccak256(abi.encode("xyz.elfi.storage.UpdatePositionMargin"));

    struct Props {
        mapping(uint256 => Request) requests;
    }

    /// @dev UpdatePositionMargin.Request struct used for storing update position margin requests
    ///
    /// @param account the address to whom the position belongs
    /// @param positionKey the unique key of the position
    /// @param marginToken the address of margin token
    /// @param updateMarginAmount the changed margin in tokens, only for isolated positions
    /// @param executionFee the execution fee for keeper
    /// @param isAdd whether the request is an additional margin
    /// @param isExecutionFeeFromTradeVault whether the execution fee collected in the first phase is deposited to the Trade Vault
    /// @param lastBlock the block in which the order was placed
    struct Request {
        address account;
        bytes32 positionKey;
        address marginToken;
        uint256 updateMarginAmount;
        uint256 executionFee;
        bool isAdd;
        bool isExecutionFeeFromTradeVault;
        uint256 lastBlock;
    }

    /// @dev Loads the `Props` storage struct from the predefined storage slot
    /// @return self UpdatePositionMargin.Props
    function load() public pure returns (Props storage self) {
        bytes32 s = KEY;
        assembly {
            self.slot := s
        }
    }

    /// @dev Creates a new update position margin request
    /// @param requestId The ID of the request to create
    /// @return UpdatePositionMargin.Request
    function create(uint256 requestId) external view returns (Request storage) {
        Props storage self = load();
        return self.requests[requestId];
    }

    /// @dev Retrieves an existing update position margin request
    /// @param requestId The ID of the request to retrieve
    /// @return UpdatePositionMargin.Request
    function get(uint256 requestId) external view returns (Request memory) {
        Props storage self = load();
        return self.requests[requestId];
    }

    /// @dev Removes an existing update position margin request
    /// @param requestId The ID of the request to remove
    function remove(uint256 requestId) external {
        Props storage self = load();
        delete self.requests[requestId];
    }
}
