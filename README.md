<img src="./docs/images/fwIcon.png" width="100" height="100" alt="Flywheel Protocol Icon">

# Flywheel Protocol

TLDR:

- A modular, permissionless protocol for transparent attribution and ERC20 reward distribution
- Enables any relationship where Users/Publishers drive conversions and get rewarded by Sponsors through various validation mechanisms
- Flexible hooks system supports diverse campaign types: advertising (AdvertisementConversion), e-commerce cashback (CashbackRewards), and custom rewards (SimpleRewards)
- Permissionless architecture allows third parties to create custom hooks for any use case
- Each hook can customize payout models, fee structures, and attribution logic while leveraging the core Flywheel infrastructure for secure token management

## Overview

Flywheel Protocol creates a decentralized incentive ecosystem where:

- **Sponsors** create campaigns and fund them with tokens (advertisers, platforms, DAOs, etc.)
- **Publishers (Optional)** drive traffic and earn rewards based on performance (only in AdvertisementConversion campaigns)
- **Attribution Providers** track conversions and submit verified data that triggers payouts to earn fees (only in AdvertisementConversion campaigns)
- **Managers** control campaign operations and submit payout data (in CashbackRewards and SimpleRewards campaigns)
- **Users** can receive incentives for completing desired actions across all campaign types

The protocol uses a modular architecture with hooks, allowing for diverse campaign types without modifying the core protocol.

## Architecture

**Core Design Principles**

- Modular design with hooks for extensibility
- Core `Flywheel.sol` protocol handles only essential functions
- Campaign-specific logic isolated in hook contracts (i.e. `AdvertisementConversion.sol` and `CashbackRewards.sol` that are derived from `CampaignHooks.sol`)
- Clean separation between protocol and implementation

## Architecture Diagram

<img src="./docs/images/modularFlywheel.png" alt="Flywheel Modular Architecture" style="max-width: 100%; height: auto;">

The diagram above illustrates how the modular Flywheel v1.1 architecture works:

- **Core Flywheel Contract**: Manages campaign lifecycle and payouts
- **TokenStore**: Each campaign has its own isolated token store
- **Attribution Hooks**: Pluggable logic for different campaign types
- **ReferralCodeRegistry**: Optional component for publisher-based campaigns
- **Participants**: Shows the flow between sponsors and recipients based on hook-specific validation

## Core Components

#### 1. **Flywheel.sol** - Core Protocol

The main contract that manages:

- Campaign lifecycle (Inactive → Active → Finalizing → Finalized)
- Reward, allocation, distribution, and deallocation of payouts
- Fee collection and distribution
- TokenStore deployment for each campaign

#### 2. **TokenStore.sol** - Campaign Treasury

- Holds campaign funds (ERC20 tokens)
- Deployed via clones for gas efficiency
- Controlled by Flywheel contract
- One TokenStore per campaign for isolation

#### 3. **CampaignHooks** - Extensibility Layer

Abstract interface that enables:

- Custom campaign logic
- Access control rules
- Attribution calculations
- Metadata management

#### 4. **ReferralCodeRegistry.sol** - Publisher & Ref Code Management

- Publisher registration and ref code generation
- Relevant to `AdvertisementConversion.sol` for Spindl/Base Ads
- Payout address management
- Multi-chain publisher identity
- Backward compatible with existing publishers

## Hook Examples

- hooks must be derived from `CampaignHooks.sol`
- for v1, we ship `AdvertisementConversion.sol`, `CashbackRewards.sol`, and `SimpleRewards.sol` but the system enables anyone to create their own hook permissionlessly (whether internal at Base or external). For instance, internally in near future if we choose to support Solana conversion events or Creator Rewards, we can deploy a new Campaign Hook that fits the specific requirements and utilize `Flywheel` core contract for managing payouts

### **AdvertisementConversion.sol**

Traditional performance marketing campaigns where publishers drive conversions and earn rewards.

**Core Features:**

- Publishers earn based on verified conversions
- Supports both onchain and offchain attribution events
- Configurable conversion configs with metadata
- Publisher allowlists for restricted campaigns
- Attribution fee collection for providers

**Campaign Creation:**

```solidity
bytes memory hookData = abi.encode(
    attributionProvider,    // Who can submit conversions
    advertiser,            // Campaign sponsor
    "https://api.spindl.xyz/metadata/...",    // Campaign metadata URI
    allowedRefCodes,       // Publisher allowlist (empty = no restrictions)
    conversionConfigs      // Array of ConversionConfig structs
);
```

**Common Reward Scenarios:**

1. **Publisher-Only Rewards (Direct Payout)**

   ```solidity
   Conversion memory conversion = Conversion({
       eventId: "unique-event-id",
       clickId: "click-12345",
       conversionConfigId: 1,
       publisherRefCode: "publisher-123",
       timestamp: uint32(block.timestamp),
       payoutRecipient: 0x1234...5678,  // Direct payout address
       payoutAmount: 10e18  // 10 tokens
   });
   ```

   - Payout goes directly to specified `payoutRecipient`
   - Useful when publisher wants specific address for rewards
   - Attribution fee deducted from `payoutAmount`

2. **ReferralCodeRegistry Lookup**

   ```solidity
   Conversion memory conversion = Conversion({
       eventId: "unique-event-id",
       clickId: "click-12345",
       conversionConfigId: 1,
       publisherRefCode: "publisher-123",
       timestamp: uint32(block.timestamp),
       payoutRecipient: address(0),  // Use registry lookup
       payoutAmount: 10e18
   });
   ```

   - When `payoutRecipient = address(0)`, system looks up publisher's payout address
   - Uses `referralCodeRegistry.getPayoutRecipient(refCode)`
   - Allows publishers to manage payout addresses centrally
   - Supports multi-chain publisher identity

3. **Onchain vs Offchain Conversions**

   ```solidity
   // Offchain conversion (e.g., email signup, purchase)
   Attribution memory offchainAttr = Attribution({
       conversion: conversion,
       logBytes: ""  // Empty for offchain events
   });

   // Onchain conversion (e.g., DEX swap, NFT mint)
   Log memory logData = Log({
       chainId: 8453,  // Base
       transactionHash: 0xabcd...,
       index: 2
   });
   Attribution memory onchainAttr = Attribution({
       conversion: conversion,
       logBytes: abi.encode(logData)  // Log data for verification
   });
   ```

4. **Conversion Config Validation**

   - `conversionConfigId = 0`: No validation, accepts any conversion type
   - `conversionConfigId > 0`: Must match registered config
     - Validates `isEventOnchain` matches presence of `logBytes`
     - Config must be active (`isActive = true`)
     - Used to enforce conversion type requirements

5. **Publisher Allowlist**

   ```solidity
   // Campaign with allowlist (only specific publishers)
   string[] memory allowedRefCodes = ["publisher-123", "publisher-456"];

   // Campaign without allowlist (any registered publisher)
   string[] memory allowedRefCodes = [];
   ```

   - Empty allowlist = any registered publisher can earn
   - Non-empty allowlist = only specified publishers allowed
   - Advertiser can add publishers via `addAllowedPublisherRefCode()`

6. **Attribution Fee Structure**

   ```solidity
   // Attribution provider sets their fee (0-100%)
   attributionProvider.setAttributionProviderFee(100); // 1% fee

   // During payout:
   uint256 attributionFee = (payoutAmount * feeBps) / 10000;
   uint256 netPayout = payoutAmount - attributionFee;
   ```

   - Attribution providers earn fees for verification work
   - Fee deducted from publisher payout, not campaign funds
   - Currently set to 0% for Base/Spindl campaigns

**Validation Rules:**

- Publisher ref code must exist in `ReferralCodeRegistry`
- If allowlist exists, publisher must be approved
- Conversion config must be active (if specified)
- Conversion type must match config (onchain/offchain)
- Only attribution provider can submit conversions
- Only advertiser can withdraw remaining funds (when finalized)

**State Transition Control:**

- **Attribution Provider**: Can perform any valid state transition (including ACTIVE→INACTIVE pause)
- **Advertiser**: Limited to ACTIVE→FINALIZING and FINALIZING→FINALIZED (after deadline)
- **Important**: If attribution provider pauses campaign (ACTIVE→INACTIVE), advertiser cannot unpause
- **Advertiser Recourse**: INACTIVE→FINALIZING→FINALIZED→withdraw funds (campaign permanently ends)
- **Design Rationale**: Attribution provider has operational control; advertiser has exit rights

### **CashbackRewards.sol**

E-commerce cashback campaigns where users receive direct rewards for purchases:

**Core Features:**

- Direct user rewards for purchases (no publishers involved)
- Uses **allocate/distribute model** (supports all payout functions including reward)
- Integrates with AuthCaptureEscrow for payment verification
- Tracks rewards per payment with allocation/distribution states
- Manager-controlled campaign operations

**Campaign Creation:**

```solidity
bytes memory hookData = abi.encode(
    manager,          // Campaign manager address
    "https://api.example.com/metadata/..."  // Campaign metadata URI
);
```

**Payout Models Supported:**

- `reward()` - Immediate payout to users
- `allocate()` - Reserve rewards for future distribution
- `distribute()` - Distribute previously allocated rewards
- `deallocate()` - Cancel allocated rewards

### **SimpleRewards.sol**

Basic rewards hook with minimal logic for flexible campaign types:

**Core Features:**

- Simple pass-through of payout data with minimal validation
- Uses **allocate/distribute model** (supports all payout functions)
- Manager-controlled campaign operations
- No complex business logic - pure reward distribution
- Suitable for custom attribution logic handled externally

**Campaign Creation:**

```solidity
bytes memory hookData = abi.encode(
    manager          // Campaign manager address
);
```

**Use Cases:**

- Custom attribution systems that handle logic externally
- Simple reward programs without complex validation
- Prototyping new campaign types before building specialized hooks
- Backend-controlled reward distribution

**Payout Models Supported:**

- `reward()` - Immediate payout to recipients
- `allocate()` - Reserve payouts for future distribution
- `distribute()` - Distribute previously allocated payouts
- `deallocate()` - Cancel allocated payouts

## Core Payout Operations

Flywheel provides four fundamental payout operations that hooks can implement based on their requirements:

### **reward()** - Immediate Payout

Transfers tokens directly to recipients immediately. Used for real-time rewards where no holding period is needed.

### **allocate()** - Reserve Future Payout

Reserves tokens for recipients without immediate transfer. Creates a "pending" state that can be claimed later or reversed.

### **distribute()** - Claim Allocated Payout

Allows recipients to claim previously allocated tokens. Converts "pending" allocations to actual token transfers.

### **deallocate()** - Cancel Allocated Payout

Cancels previously allocated tokens, returning them to the campaign treasury. Only works on unclaimed allocations.

## Hook Implementation Comparison

Different hooks implement these operations based on their specific use cases:

| **Aspect**       | **AdvertisementConversion**     | **CashbackRewards**            | **SimpleRewards**             |
| ---------------- | ------------------------------- | ------------------------------ | ----------------------------- |
| **Controller**   | Attribution Provider            | Manager                        | Manager                       |
| **Use Case**     | Publisher performance marketing | E-commerce cashback            | Flexible reward distribution  |
| **reward()**     | ✅ Immediate publisher payouts  | ✅ Direct user cashback        | ✅ Direct recipient payouts   |
| **allocate()**   | ❌ Not implemented              | ✅ Reserve cashback for claims | ✅ Reserve payouts for claims |
| **distribute()** | ❌ Not implemented              | ✅ Users claim cashback        | ✅ Recipients claim rewards   |
| **deallocate()** | ❌ Not implemented              | ✅ Cancel unclaimed cashback   | ✅ Cancel unclaimed rewards   |
| **Fees**         | ✅ Attribution provider fees    | ❌ No fees                     | ❌ No fees                    |
| **Validation**   | Complex (ref codes, configs)    | Medium (payment verification)  | Minimal (pass-through)        |
| **Publishers**   | ✅ Via ReferralCodeRegistry     | ❌ Direct to users             | ❌ Direct to recipients       |

## Detailed Hook Behaviors

### AdvertisementConversion: Attribution Provider Model

**Who Controls**: Attribution providers verify conversions and submit payouts
**Payout Flow**: Immediate rewards only - no allocation/distribution needed
**Validation**: Complex publisher verification, conversion configs, allowlists
**Fees**: Attribution providers earn percentage-based fees

### CashbackRewards: Manager Model

**Who Controls**: Managers (typically payment processors or platforms)
**Payout Flow**: Full allocate/distribute model for flexible cashback claims
**Validation**: Payment verification via AuthCaptureEscrow integration
**Fees**: No fees - direct cashback to users

### SimpleRewards: Manager Model

**Who Controls**: Managers (typically backend services or trusted controllers)  
**Payout Flow**: Full allocate/distribute model for maximum flexibility
**Validation**: Minimal - simple pass-through of payout data
**Fees**: No fees - pure reward distribution

### Gas Optimization

- TokenStore uses clone pattern (not full deployment) saving ~90% deployment gas
- Batch attribution submissions supported via arrays
- Pull-based payout distribution prevents reentrancy

## Use Case Examples

The modular architecture supports diverse incentive programs:

### 1. **Traditional Advertising**

- **Sponsor**: Brand or Advertiser
- **Attribution Provider**: Spindl or similar analytics service
- **Hook**: `AdvertisementConversion`
- **Flow**: Publishers drive traffic → Users convert → Attribution provider verifies → Publishers/users earn

### 2. **E-commerce Cashback**

- **Sponsor**: E-commerce platform (e.g., Shopify or Base)
- **Manager**: Payment processor or platform itself
- **Hook**: `CashbackRewards`
- **Flow**: Users make purchases → Payment confirmed → Payouts issued → Users receive cashback

### 3. **Simple Reward Distribution**

- **Sponsor**: Any entity wanting to distribute rewards
- **Manager**: Backend service or trusted controller
- **Hook**: `SimpleRewards`
- **Flow**: Actions tracked externally → Manager submits payout data → Recipients claim rewards

### 4. **Creator Rewards**

- **Sponsor**: Social platform or DAO
- **Attribution Provider**: TBD
- **Hook**: Custom creator rewards hook
- **Flow**: Creators produce content → Engagement tracked → Attribution verified → Creators earn

### 5. **DeFi Incentives**

- **Sponsor**: DeFi protocol
- **Attribution Provider**: TBD but could be onchain indexer or protocol itself
- **Hook**: Custom DeFi activity hook
- **Flow**: Users perform actions → Blockchain events indexed → Payouts issued → Users earn

### 6. **Other (Example: Builder Rewards)**

- We created Flywheel in such a way that others can hook into the architecture quite easily
- **Sponsor**: DAO or protocol
- **Manager**: Development team or DAO governance
- **Hook**: Custom builder rewards hook
- **Flow**: Builders complete milestones → Contributions verified → Payouts issued → Rewards distributed

## Key Improvements

### Modularity

- Core protocol separated from campaign logic
- New campaign types via hooks without protocol changes
- Clean separation of concerns

### Gas Efficiency

- Clone pattern for TokenStore deployment
- Batch operations for attribution
- Optimized storage patterns
- Significant gas optimization through efficient patterns

### Flexibility

- Support for any ERC20 token
- Custom attribution logic per campaign
- Extensible metadata system
- Plugin-based architecture

### Security

- Minimal core protocol surface area
- Campaign isolation through separate TokenStores
- Hook-based access control
- Reduced attack vectors

## Getting Started

### Installation

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/spindl-xyz/flywheel.git

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Testing

```bash
# Build
forge build

# Run tests
forge test -vv

# Run specific test
forge test --match-test testName -vvv

# Gas report
forge test --gas-report

# Coverage
forge coverage --ir-minimum
```

## Usage Examples

### Creating a Campaign

```solidity
// Deploy hook contract (or use existing)
AdvertisementConversion hook = new AdvertisementConversion(flywheel);

// Prepare campaign data
bytes memory hookData = abi.encode(
    payoutProvider,        // Who can submit payouts
    msg.sender,           // Sponsor
    "ipfs://metadata"     // Campaign details
);

// Create campaign
address campaign = flywheel.createCampaign(
    address(hook),
    nonce,
    hookData
);

// Fund campaign
IERC20(token).transfer(campaign, 100_000e18);

// Activate campaign for payouts
flywheel.updateStatus(campaign, CampaignStatus.ACTIVE, "");
```

### Payout Operations

The Flywheel protocol supports four main payout operations:

#### Immediate Rewards

```solidity
// Immediate payout to recipients
bytes memory hookData = abi.encode(
    recipients,
    amounts,
    // hook-specific data
);

flywheel.reward(campaign, token, hookData);
```

#### Allocate Payouts

```solidity
// Reserve payouts for future distribution
bytes memory hookData = abi.encode(
    recipients,
    amounts,
    // hook-specific data
);

flywheel.allocate(campaign, token, hookData);
```

#### Distribute Allocated Payouts

```solidity
// Distribute previously allocated payouts
bytes memory hookData = abi.encode(
    recipients,
    amounts,
    // hook-specific data
);

flywheel.distribute(campaign, token, hookData);
```

#### Deallocate Payouts

```solidity
// Remove allocated payouts (cancel allocations)
bytes memory hookData = abi.encode(
    recipients,
    amounts,
    // hook-specific data
);

flywheel.deallocate(campaign, token, hookData);
```

### Collecting Fees

```solidity
// Attribution providers collect accumulated fees
flywheel.collectFees(campaign, token, feeRecipient);
```

## Campaign Lifecycle

### State Transitions and Access Control

| State          | Who Can Update To          | Next Valid States    | Payout Functions Available                       |
| -------------- | -------------------------- | -------------------- | ------------------------------------------------ |
| **INACTIVE**   | Anyone (campaign creation) | ACTIVE               | None                                             |
| **ACTIVE**     | Hook-dependent             | INACTIVE, FINALIZING | reward(), allocate(), distribute(), deallocate() |
| **FINALIZING** | Hook-dependent             | FINALIZED            | reward(), allocate(), distribute(), deallocate() |
| **FINALIZED**  | None (terminal state)      | None                 | None                                             |

### Detailed State Descriptions

1. **INACTIVE State**

   - **Created by**: Anyone calling `createCampaign()` (this is will be considered Advertiser)
   - **Purpose**: Initial state after campaign creation
   - **Actions allowed**: Fund campaign, update metadata
   - **Who can transition to ACTIVE**:
     - **AdvertisementConversion**: Attribution Provider (always), Advertiser (limited)
     - **CashbackRewards**: Status changes not supported
     - **SimpleRewards**: Manager-controlled transitions

2. **ACTIVE State**

   - **Purpose**: Campaign is live and processing payouts
   - **Payout functions**: All four functions available based on hook implementation
     - **AdvertisementConversion**: Only `reward()` implemented
     - **CashbackRewards**: `reward()`, `allocate()`, `distribute()`, `deallocate()` implemented
     - **SimpleRewards**: `reward()`, `allocate()`, `distribute()`, `deallocate()` implemented
   - **Who can transition**:
     - **AdvertisementConversion**:
       - Attribution Provider: Can go to ANY state (including back to INACTIVE)
       - Advertiser: Can only go to FINALIZING
     - **CashbackRewards**: Status changes not supported (campaigns stay ACTIVE)
     - **SimpleRewards**: Manager-controlled transitions

3. **FINALIZING State**

   - **Purpose**: Grace period for final payouts before campaign closure
   - **Attribution deadline**: Set when entering this state (configurable, default 7 days)
   - **Payout functions**: Still available for processing lagging attributions
   - **Who can transition to FINALIZED**:
     - **AdvertisementConversion**:
       - Attribution Provider: Can transition immediately
       - Advertiser: Only after attribution deadline passes
     - **CashbackRewards**: Status changes not supported
     - **SimpleRewards**: Manager-controlled transitions

4. **FINALIZED State**
   - **Purpose**: Campaign permanently closed
   - **Payout functions**: None available
   - **Fund withdrawal**:
     - **AdvertisementConversion**: Only Advertiser
     - **CashbackRewards**: Only Manager
     - **SimpleRewards**: Only Manager

### Role Definitions by Hook Type

#### AdvertisementConversion Campaigns

- **Advertiser**: Campaign sponsor who funds the campaign
- **Attribution Provider**: Authorized to submit conversion data and earn fees
- **Publishers**: Earn rewards based on conversions (managed via ReferralCodeRegistry)

#### CashbackRewards Campaigns

- **Manager**: Controls campaign lifecycle and processes payment-based rewards
- **Users**: Receive cashback rewards directly (no publishers involved)

#### SimpleRewards Campaigns

- **Manager**: Controls all campaign operations and payout submissions
- **Recipients**: Receive rewards based on manager-submitted payout data

## Creating Custom Hooks

Implement the `CampaignHooks` interface:

```solidity
contract MyCustomHook is CampaignHooks {
    constructor(address flywheel) CampaignHooks(flywheel) {}

    function createCampaign(address campaign, bytes calldata data)
        external override onlyFlywheel {
        // Initialize campaign state
        // Set attribution provider(s)
    }

    function onReward(
        address sender,
        address campaign,
        address token,
        bytes calldata data
    ) external override onlyFlywheel
      returns (Payout[] memory, uint256 fee) {
        // Verify sender is authorized attribution provider
        // Validate payout data
        // Calculate payouts and fees
        // Return results
    }

    function onAllocate(
        address sender,
        address campaign,
        address token,
        bytes calldata data
    ) external override onlyFlywheel
      returns (Payout[] memory, uint256 fee) {
        // Similar implementation for allocation
    }

    function onDistribute(
        address sender,
        address campaign,
        address token,
        bytes calldata data
    ) external override onlyFlywheel
      returns (Payout[] memory, uint256 fee) {
        // Implementation for distribution
    }

    function onDeallocate(
        address sender,
        address campaign,
        address token,
        bytes calldata data
    ) external override onlyFlywheel
      returns (Payout[] memory) {
        // Implementation for deallocation
    }

    // Implement other required functions...
}
```

## Protocol Participants

### Sponsors

- Fund campaigns (advertisers, platforms, DAOs, protocols)
- Configure campaign rules via hooks
- Set trusted controllers (attribution providers for AdvertisementConversion, managers for other hooks)
- Monitor campaign performance
- Withdraw unused funds

### Publishers

- Register via ReferralCodeRegistry
- Drive traffic using ref codes
- Claim accumulated rewards
- View earnings across campaigns

### Attribution Providers

- Track conversion events (onchain/offchain)
- Verify event authenticity
- Submit payout operations in batches
- Earn fees for accurate attribution
- Maintain reputation for reliability

### Users

- Complete desired actions
- Receive direct incentives (if configured)
- Transparent reward tracking

## Security Considerations

- **Campaign Isolation**: Each campaign has its own TokenStore
- **Immutable Hooks**: Campaign logic cannot be changed after creation
- **Minimal Core**: Reduced attack surface in core protocol
- **Access Control**: Hook-based permissions for each operation
- **No Reentrancy**: Pull-based reward distribution
- **Attribution Trust**: Sponsors choose their attribution providers

## Audits

The modular architecture is currently undergoing audit.

## Deployment

The protocol is designed for deployment on Ethereum L2s and can technically be deployed on any EVM. Primary focus will be to have attribution and payouts to happen on Base for now although we can attribute data from other EVMs (Opt, Arb, etc.)

### Deployment Scripts

Foundry deployment scripts are available in the `scripts/` directory for deploying all protocol contracts:

- **`DeployFlywheel.s.sol`** - Deploys the core Flywheel contract
- **`DeployPublisherRegistry.s.sol`** - Deploys the upgradeable ReferralCodeRegistry with proxy
- **`DeployAdvertisementConversion.s.sol`** - Deploys the AdvertisementConversion hook
- **`DeployAll.s.sol`** - Orchestrates deployment of all contracts in the correct order

### Deployment Configuration

#### Required Parameters

##### Owner Address

All deployment scripts require an owner address that will have administrative control over the deployed contracts. This address will be able to:

- Upgrade the ReferralCodeRegistry contract (via UUPS proxy)
- Configure protocol parameters
- Manage contract permissions

##### Chain ID

The target chain is specified via the `--rpc-url` parameter. Examples:

- **Base Mainnet**: `https://mainnet.base.org`
- **Base Sepolia**: `https://sepolia.base.org`

#### Etherscan Verification

Contract verification uses the `ETHERSCAN_API_KEY` from your `.env` file:

- **Base networks**: Use your Basescan API key
- **Other networks**: Use the appropriate explorer API key

Create a `.env` file in the project root:

```bash
PRIVATE_KEY=your_private_key_here
ETHERSCAN_API_KEY=your_basescan_api_key_here
```

**Important**: Load your environment variables before running commands:

```bash
source .env
```

#### Signer Address (Optional)

The ReferralCodeRegistry supports an optional "signer" address that can:

- Register publishers with custom ref codes (instead of auto-generated ones)
- Register publishers on behalf of others
- Enable backend integration for programmatic publisher management

**When to use:**

- Set to `address(0)` for simple deployments (self-registration only)
- Set to your backend service address for advanced publisher management

### Deployment Examples

#### Deploy All Contracts (No Signer)

```bash
# Base Sepolia - Replace OWNER_ADDRESS with your desired owner address
forge script scripts/DeployAll.s.sol --sig "run(address)" OWNER_ADDRESS --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY --broadcast --verify

# Example with specific owner
forge script scripts/DeployAll.s.sol --sig "run(address)" 0x7116F87D6ff2ECa5e3b2D5C5224fc457978194B2 --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY --broadcast --verify
```

#### Deploy All Contracts (With Signer)

```bash
# With both owner and signer addresses for custom publisher registration
forge script scripts/DeployAll.s.sol --sig "run(address,address)" OWNER_ADDRESS SIGNER_ADDRESS --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY --broadcast --verify

# Example with specific addresses
forge script scripts/DeployAll.s.sol --sig "run(address,address)" 0x7116F87D6ff2ECa5e3b2D5C5224fc457978194B2 0x1234567890123456789012345678901234567890 --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY --broadcast --verify
```

#### Deploy Individual Contracts

```bash
# Deploy only Flywheel (no owner parameter needed)
forge script scripts/DeployFlywheel.s.sol --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY --broadcast --verify

# Deploy only ReferralCodeRegistry with owner
forge script scripts/DeployPublisherRegistry.s.sol --sig "run(address)" OWNER_ADDRESS --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY --broadcast --verify

# Deploy only ReferralCodeRegistry with owner and signer
forge script scripts/DeployPublisherRegistry.s.sol --sig "run(address,address)" OWNER_ADDRESS SIGNER_ADDRESS --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY --broadcast --verify
```

### Deployment Order

The scripts handle dependencies automatically, but the deployment order is:

1. **Flywheel** (independent)
2. **ReferralCodeRegistry** (independent, upgradeable via UUPS proxy)
3. **AdvertisementConversion** (requires Flywheel and ReferralCodeRegistry addresses)

### Contract Ownership

The owner address is specified during deployment and will have administrative control over:

- **ReferralCodeRegistry**: Can upgrade the contract via UUPS proxy pattern
- **AdvertisementConversion**: Can configure protocol parameters and manage permissions

**Important**: Choose your owner address carefully as it will have significant control over the protocol. Consider using a multisig wallet for production deployments.

### Post-Deployment

After deployment, you'll receive addresses for:

- **Flywheel**: Core protocol contract
- **ReferralCodeRegistry**: Publisher management (proxy address)
- **AdvertisementConversion**: Hook for ad campaigns
- **TokenStore Implementation**: Template for campaign treasuries (auto-deployed by Flywheel)
