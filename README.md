
# Elfi Protocol contest details

- Join [Sherlock Discord](https://discord.gg/MABEWyASkp)
- Submit findings using the issue page in your private contest repo (label issues as med or high)
- [Read for more details](https://docs.sherlock.xyz/audits/watsons)

# Q&A

### Q: On what chains are the smart contracts going to be deployed?
Arbitrum & Base
___

### Q: If you are integrating tokens, are you allowing only whitelisted tokens to work with the codebase or any complying with the standard? Are they assumed to have certain properties, e.g. be non-reentrant? Are there any types of <a href="https://github.com/d-xo/weird-erc20" target="_blank" rel="noopener noreferrer">weird tokens</a> you want to integrate?
Only standard ERC20 tokens.
___

### Q: Are the admins of the protocols your contracts integrate with (if any) TRUSTED or RESTRICTED? If these integrations are trusted, should auditors also assume they are always responsive, for example, are oracles trusted to provide non-stale information, or VRF providers to respond within a designated timeframe?
Oracles: We use our own offline oracle mechanism, where the oracle protocol administrator is only responsible for providing the oracle price. 
Subsequently, we consider using Chainlink for deviation verification on-chain.

Both are TRUSTED.
___

### Q: Are there any protocol roles? Please list them and provide whether they are TRUSTED or RESTRICTED, or provide a more comprehensive description of what a role can and can't do/impact.
We have the following protocol roles.
Admin Role (TRUSTED): Used for managing other Roles
Deploy Role (RESTRICTED): Only used for smart contract deployment and dynamic upgrades.
Config Role (RESTRICTED): Only used to modify some business configuration information, such as adding a new Market. 
Keeper Role (RESTRICTED): Only used for executing two-phase commits and scheduled tasks.
___

### Q: For permissioned functions, please list all checks and requirements that will be made before calling the function.
1. All two-phase commit functions (functions starting with 'execute' in Facet) can only be called by the Keeper Role, such as executeOrder().
2. All first-phase cancellation functions can only be called by the Keeper Role (except for cancelOrder, which users can also use to cancel orders).
3. The set functions in ConfigFacet can only be called by the Config Role, such as setPoolConfig.
4. All fund transfers out of the Vault can only be handled by the smart contract Diamond.
5. All StakeToken can only be minted and burned by the smart contract Diamond, such as users staking ETH to receive StakeToken.
6. DiamondCutFacet.diamondCut can only be called by Admin.
___

### Q: Is the codebase expected to comply with any EIPs? Can there be/are there any deviations from the specification?
The codebase is optionally compliant (compliancy issues will not be valid Medium/High) with EIP-2535, and we have added an additional layer of process structure on top of EIP-2535 to facilitate the sharing of more
___

### Q: Are there any off-chain mechanisms or off-chain procedures for the protocol (keeper bots, arbitrage bots, etc.)?
Our offline mechanisms include a Keeper bot and Oracle Service. The Keeper bot is used for executing two-phase commits and triggering scheduled tasks. The Oracle Service is used to integrate top CEXs and DEXs to obtain ultra-low latency oracle prices, meeting the low latency requirements for Portfolio Margin

The platform involves collateral liquidation, where third-party users can execute liquidation and obtain reward profits by calling the liquidation contract through self-developed liquidation bot.
___

### Q: Are there any hardcoded values that you intend to change before (some) deployments?
No
___

### Q: If the codebase is to be deployed on an L2, what should be the behavior of the protocol in case of sequencer issues (if applicable)? Should Sherlock assume that the Sequencer won't misbehave, including going offline?
Yes, It should be assumed the Sequencer wont misbehave.
___

### Q: Should potential issues, like broken assumptions about function behavior, be reported if they could pose risks in future integrations, even if they might not be an issue in the context of the scope? If yes, can you elaborate on properties/invariants that should hold?
yes
___

### Q: Please discuss any design choices you made.
The system risk control and liquidation require millisecond-level latency oracles. We have developed our own ultra-low latency offline oracles, which fetch the latest price from the oracle during risk control and liquidation execution.

To improve code reusability, we have added a process layer on top of the Diamond standard model, encapsulating all core business logic into the process. Facets are more used for parameter safety verification, business assembly, and other processing tasks.

Subsequently, we consider using Chainlink for deviation verification on-chain.
___

### Q: Please list any known issues/acceptable risks that should not result in a valid finding.
1. Regarding the Pool's Mint and Redemption operations, there is no emergency disable function; we are addressing this issue.
2. The smart contract lacks a Pause feature
___

### Q: We will report issues where the core protocol functionality is inaccessible for at least 7 days. Would you like to override this value?
No, keeping the default value is fine.
___

### Q: Please provide links to previous audits (if any).
This is our first audit
___

### Q: Please list any relevant protocol resources.
Testnet: https://sepolia.elfi.xyz/trade/ETHUSD
Docs: https://docs.elfi.xyz/
___

### Q: Additional audit information.
No
___



# Audit scope


[elfi-perp-contracts @ 592f4ca0ea256d9474012d9665796bb6e453f107](https://github.com/0xCedar/elfi-perp-contracts/tree/592f4ca0ea256d9474012d9665796bb6e453f107)
- [elfi-perp-contracts/contracts/facets/AccountFacet.sol](elfi-perp-contracts/contracts/facets/AccountFacet.sol)
- [elfi-perp-contracts/contracts/facets/DiamondCutFacet.sol](elfi-perp-contracts/contracts/facets/DiamondCutFacet.sol)
- [elfi-perp-contracts/contracts/facets/DiamondLoupeFacet.sol](elfi-perp-contracts/contracts/facets/DiamondLoupeFacet.sol)
- [elfi-perp-contracts/contracts/facets/OrderFacet.sol](elfi-perp-contracts/contracts/facets/OrderFacet.sol)
- [elfi-perp-contracts/contracts/facets/PositionFacet.sol](elfi-perp-contracts/contracts/facets/PositionFacet.sol)
- [elfi-perp-contracts/contracts/facets/RoleAccessControlFacet.sol](elfi-perp-contracts/contracts/facets/RoleAccessControlFacet.sol)
- [elfi-perp-contracts/contracts/facets/StakeFacet.sol](elfi-perp-contracts/contracts/facets/StakeFacet.sol)
- [elfi-perp-contracts/contracts/process/AccountProcess.sol](elfi-perp-contracts/contracts/process/AccountProcess.sol)
- [elfi-perp-contracts/contracts/process/AssetsProcess.sol](elfi-perp-contracts/contracts/process/AssetsProcess.sol)
- [elfi-perp-contracts/contracts/process/CancelOrderProcess.sol](elfi-perp-contracts/contracts/process/CancelOrderProcess.sol)
- [elfi-perp-contracts/contracts/process/DecreasePositionProcess.sol](elfi-perp-contracts/contracts/process/DecreasePositionProcess.sol)
- [elfi-perp-contracts/contracts/process/FeeProcess.sol](elfi-perp-contracts/contracts/process/FeeProcess.sol)
- [elfi-perp-contracts/contracts/process/GasProcess.sol](elfi-perp-contracts/contracts/process/GasProcess.sol)
- [elfi-perp-contracts/contracts/process/IncreasePositionProcess.sol](elfi-perp-contracts/contracts/process/IncreasePositionProcess.sol)
- [elfi-perp-contracts/contracts/process/LpPoolProcess.sol](elfi-perp-contracts/contracts/process/LpPoolProcess.sol)
- [elfi-perp-contracts/contracts/process/LpPoolQueryProcess.sol](elfi-perp-contracts/contracts/process/LpPoolQueryProcess.sol)
- [elfi-perp-contracts/contracts/process/MarketProcess.sol](elfi-perp-contracts/contracts/process/MarketProcess.sol)
- [elfi-perp-contracts/contracts/process/MarketQueryProcess.sol](elfi-perp-contracts/contracts/process/MarketQueryProcess.sol)
- [elfi-perp-contracts/contracts/process/MintProcess.sol](elfi-perp-contracts/contracts/process/MintProcess.sol)
- [elfi-perp-contracts/contracts/process/OrderProcess.sol](elfi-perp-contracts/contracts/process/OrderProcess.sol)
- [elfi-perp-contracts/contracts/process/PositionMarginProcess.sol](elfi-perp-contracts/contracts/process/PositionMarginProcess.sol)
- [elfi-perp-contracts/contracts/process/PositionQueryProcess.sol](elfi-perp-contracts/contracts/process/PositionQueryProcess.sol)
- [elfi-perp-contracts/contracts/process/RedeemProcess.sol](elfi-perp-contracts/contracts/process/RedeemProcess.sol)
- [elfi-perp-contracts/contracts/process/VaultProcess.sol](elfi-perp-contracts/contracts/process/VaultProcess.sol)
- [elfi-perp-contracts/contracts/router/Diamond.sol](elfi-perp-contracts/contracts/router/Diamond.sol)
- [elfi-perp-contracts/contracts/router/DiamondInit.sol](elfi-perp-contracts/contracts/router/DiamondInit.sol)
- [elfi-perp-contracts/contracts/storage/Account.sol](elfi-perp-contracts/contracts/storage/Account.sol)
- [elfi-perp-contracts/contracts/storage/LibDiamond.sol](elfi-perp-contracts/contracts/storage/LibDiamond.sol)
- [elfi-perp-contracts/contracts/storage/LpPool.sol](elfi-perp-contracts/contracts/storage/LpPool.sol)
- [elfi-perp-contracts/contracts/storage/Order.sol](elfi-perp-contracts/contracts/storage/Order.sol)
- [elfi-perp-contracts/contracts/storage/Position.sol](elfi-perp-contracts/contracts/storage/Position.sol)
- [elfi-perp-contracts/contracts/storage/RoleAccessControl.sol](elfi-perp-contracts/contracts/storage/RoleAccessControl.sol)
- [elfi-perp-contracts/contracts/storage/UsdPool.sol](elfi-perp-contracts/contracts/storage/UsdPool.sol)
- [elfi-perp-contracts/contracts/utils/TransferUtils.sol](elfi-perp-contracts/contracts/utils/TransferUtils.sol)
- [elfi-perp-contracts/contracts/vault/LpVault.sol](elfi-perp-contracts/contracts/vault/LpVault.sol)
- [elfi-perp-contracts/contracts/vault/PortfolioVault.sol](elfi-perp-contracts/contracts/vault/PortfolioVault.sol)
- [elfi-perp-contracts/contracts/vault/StakeToken.sol](elfi-perp-contracts/contracts/vault/StakeToken.sol)
- [elfi-perp-contracts/contracts/vault/TradeVault.sol](elfi-perp-contracts/contracts/vault/TradeVault.sol)
- [elfi-perp-contracts/contracts/vault/Vault.sol](elfi-perp-contracts/contracts/vault/Vault.sol)

