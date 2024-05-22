// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title Mint Storage
/// @dev Library for mint storage
library Mint {
    bytes32 constant MINT_KEY = keccak256(abi.encode("xyz.elfi.storage.Mint"));

    /// @dev Struct to store minting requests
    /// @param requests A mapping from request IDs to Mint.Request
    struct Props {
        mapping(uint256 => Request) requests;
    }

    /// @dev Struct to store details of a minting request
    /// @param account The address of the account making the request
    /// @param stakeToken The address of the pool
    /// @param requestToken The address of the token being used
    /// @param requestTokenAmount The total amount of tokens for minting
    /// @param walletRequestTokenAmount The amount of tokens from the wallet for minting.
    ///        When it is zero, it means that all of the requestTokenAmount is transferred from the user's trading account(Account).
    /// @param minStakeAmount The minimum staking return amount expected
    /// @param executionFee The execution fee for the keeper
    /// @param isCollateral Whether the request token is used as collateral
    /// @param isExecutionFeeFromLpVault Whether the execution fee collected in the first phase is deposited to the Lp Vault
    struct Request {
        address account;
        address stakeToken;
        address requestToken;
        uint256 requestTokenAmount;
        uint256 walletRequestTokenAmount;
        uint256 minStakeAmount;
        uint256 executionFee;
        bool isCollateral;
        bool isExecutionFeeFromLpVault;
    }

    function load() public pure returns (Props storage self) {
        bytes32 s = MINT_KEY;
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
