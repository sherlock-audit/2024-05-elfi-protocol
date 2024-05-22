// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title Update Position Leverage Storage
/// @dev Library for update position leverage requests storage 
library UpdateLeverage {
    bytes32 constant KEY = keccak256(abi.encode("xyz.elfi.storage.UpdateLeverage"));

    struct Props {
        mapping(uint256 => Request) requests;
    }

    /// @dev UpdateLeverage.Request struct used for storing update position leverage requests
    ///
    /// @param account the address to whom the position belongs
    /// @param symbol the market to which the position belongs
    /// @param isLong  whether the direction of the position is long 
    /// @param isExecutionFeeFromTradeVault whether the execution fee collected in the first phase is deposited to the Trade Vault
    /// @param isCrossMargin whether it is a cross-margin position
    /// @param leverage the new leverage of the position
    /// @param marginToken the address of margin token
    /// @param addMarginAmount the add margin in tokens when reducing leverage, only for isolated positions
    /// @param executionFee the execution fee for keeper
    /// @param lastBlock the block in which the order was placed
    struct Request {
        address account;
        bytes32 symbol;
        bool isLong;
        bool isExecutionFeeFromTradeVault;
        bool isCrossMargin;
        uint256 leverage;
        address marginToken;
        uint256 addMarginAmount;
        uint256 executionFee;
        uint256 lastBlock;
    }

    /// @dev Loads the `Props` storage struct from the predefined storage slot
    /// @return self UpdateLeverage.Props
    function load() public pure returns (Props storage self) {
        bytes32 s = KEY;
        assembly {
            self.slot := s
        }
    }

    /// @dev Creates a new update position leverage request
    /// @param requestId The ID of the request to create
    /// @return UpdateLeverage.Request
    function create(uint256 requestId) external view returns (Request storage) {
        Props storage self = load();
        return self.requests[requestId];
    }

    /// @dev Retrieves an existing update position leverage request
    /// @param requestId The ID of the request to retrieve
    /// @return UpdateLeverage.Request
    function get(uint256 requestId) external view returns (Request memory) {
        Props storage self = load();
        return self.requests[requestId];
    }

    /// @dev Removes an existing update position leverage request
    /// @param requestId The ID of the request to remove
    function remove(uint256 requestId) external {
        Props storage self = load();
        delete self.requests[requestId];
    }
}
