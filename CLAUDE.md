# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing

- `forge build` - Compile all Solidity contracts
- `forge test` - Run all tests with basic verbosity
- `forge test -vv` - Run tests with increased verbosity (recommended)
- `forge test -vvv` - Run tests with maximum verbosity for debugging
- `forge test --match-test testName` - Run specific test by name
- `forge test --gas-report` - Generate gas usage report
- `forge coverage --ir-minimum` - Generate test coverage report

### Development Workflow

- `forge clean` - Clean build artifacts
- `forge fmt` - Format Solidity code
- Always run `forge test -vv` before committing changes

## Architecture Overview

### Core Protocol (Modular Design)

**Flywheel.sol** - Main protocol contract that:

- Manages campaign lifecycle (CREATED → OPEN → PAUSED → CLOSED → FINALIZED)
- Handles attribution and payout accumulation through `attribute()` function
- Manages fee collection for attribution providers
- Deploys isolated TokenStore contracts per campaign via Clones pattern

**TokenStore.sol** - Campaign treasury:

- Minimal contract deployed via clones for gas efficiency
- Holds ERC20 tokens for each campaign in isolation
- Only callable by the Flywheel contract (owner)

**CampaignHooks.sol** - Abstract base for extensible campaign logic:

- Defines interface for custom campaign types
- Enables permissionless creation of new campaign behaviors
- Hooks control access, attribution rules, and metadata

### Hook Implementations

**AdvertisementConversion.sol** - Traditional performance marketing:

- Publishers earn based on verified conversions
- Supports both onchain and offchain attribution events
- Uses **immediate payout model** (`reward` only - no allocate/distribute)
- Integrates with Ref for publisher management
- Used for Spindl/Base Ads campaigns

**CommerceCashback.sol** - E-commerce cashback campaigns:

- Direct user rewards for purchases (no publishers involved)
- Uses **allocate/distribute model** (supports all payout functions including reward)
- Integrates with AuthCaptureEscrow for payment verification
- Percentage-based cashback calculation

### Supporting Components

**ReferralCodeRegistry.sol** - Ref code management:

- Ref code registration and ref code generation
- Payout address management across multiple chains
- Backward compatible with legacy publishers

## Key Patterns

### Campaign Creation Flow

1. Deploy hook contract (or use existing)
2. Call `flywheel.createCampaign(hookAddress, nonce, hookData)`
3. TokenStore is automatically cloned and configured
4. Fund campaign by transferring tokens to the campaign address
5. Update status to OPEN to begin accepting attributions

### Attribution Flow

The Flywheel protocol supports two payout models depending on the hook implementation:

#### Immediate Payout Model (AdvertisementConversion)

1. Attribution provider calls `flywheel.reward(campaign, token, attributionData)`
2. Hook validates attribution data and sender permissions
3. Hook returns array of payouts and attribution fee
4. Flywheel immediately transfers tokens to recipients
5. Attribution provider fees are accumulated for later collection

#### Allocate/Distribute Model (CashbackRewards and others)

1. Attribution provider calls `flywheel.allocate(campaign, token, attributionData)`
2. Hook validates and returns payouts to be allocated (not immediately sent)
3. Payouts are accumulated in the Flywheel contract
4. Recipients call `flywheel.distribute()` to claim their allocated rewards
5. `flywheel.deallocate()` can reverse allocations before distribution

### Gas Optimization

- TokenStore uses clone pattern (not full deployment) saving ~90% deployment gas
- Batch attribution submissions supported via arrays
- Pull-based payout distribution prevents reentrancy

### Access Control

- Campaign hooks define who can submit attributions
- Each campaign specifies trusted attribution providers
- Status transitions controlled by hooks with custom logic

## File Structure

- `src/` - Core protocol contracts
  - `Flywheel.sol` - Main protocol
  - `CampaignHooks.sol` - Hook interface
  - `TokenStore.sol` - Campaign treasury
  - `ReferralCodeRegistry.sol` - Publisher & Ref code management
  - `hooks/` - Hook implementations
- `test/` - Foundry tests (use -vv flag for proper verbosity)
- `lib/` - Dependencies (OpenZeppelin, forge-std, commerce-payments)
- `archive/` - Legacy contracts from monolithic architecture

## Architecture Evolution

This codebase represents a complete redesign from a monolithic `FlywheelCampaigns.sol` to a modular hooks-based architecture. The archived contracts in `src/archive/` and `test/archive/` represent the old system and should not be modified.

## Testing Notes

- Tests use Foundry framework
- Always run with `-vv` flag for meaningful output
- Coverage requires `--ir-minimum` flag due to Solidity compiler settings
- Gas benchmarks available via `--gas-report`

## Claude Permissions and Workflow

- Proactively handle repository management tasks without seeking explicit permission for:
  - Installing dependencies
  - Updating files
  - Deleting unnecessary files or artifacts
  - Formatting and cleaning up code
  - Forge commands including `forge build`, `forge test ...` etc

## Solidity Coding Standards

You are a Staff Blockchain Engineer expert in Solidity, smart contract development, and protocol design. You write clean, secure, and properly documented smart contracts. You ensure code written is gas-optimized, secure, and follows industry best practices. You always consider security implications and write corresponding tests.

### Core Principles

- **Security First**: Always prioritize security over convenience. Follow checks-effects-interactions pattern.
- **Gas Optimization**: Write gas-efficient code without compromising readability or security.
- **Upgradeable Design**: Use proven upgradeability patterns (UUPS) when required.
- **Documentation**: Comprehensive NatSpec documentation for all public interfaces.

### Style Guide Compliance

#### Base Standard

Unless an exception or addition is specifically noted, we follow the [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html).

#### Key Exceptions and Additions

##### 1. Internal Library Functions

**Names of internal functions in a library should NOT have an underscore prefix.**

```solidity
// GOOD: Clear and readable
Library.function()

// BAD: Visually confusing
Library._function()
```

##### 2. Error Handling

- **Prefer custom errors** over `require` strings for gas efficiency
- **Custom error names should be CapWords style** (e.g., `InsufficientBalance`, `Unauthorized`)

##### 3. Events

- **Event names should be past tense** - Events track things that _happened_
- Using past tense helps avoid naming collisions with structs or functions
- Example: `TokenTransferred` not `TokenTransfer`

##### 4. Mappings

**Prefer named parameters in mapping types** for clarity:

```solidity
// GOOD
mapping(address account => mapping(address asset => uint256 amount)) public balances;

// BAD
mapping(uint256 => mapping(address => uint256)) public balances;
```

##### 5. Contract Architecture

- **Prefer composition over inheritance** when functions could reasonably be in separate contracts
- **Avoid writing interfaces** unless absolutely necessary - they separate NatSpec from logic
- **Avoid using assembly** unless gas savings are very consequential (>25%)

##### 6. Imports

**Use named imports** and order alphabetically:

```solidity
// GOOD
import {Contract} from "./contract.sol";

// Group imports by external and local
import {Math} from '/solady/Math.sol';

import {MyHelper} from './MyHelper.sol';
```

##### 7. Testing Standards

- **Test file names**: `ContractName.t.sol`
- **Test contract names**: `ContractNameTest` or `FunctionNameTest`
- **Test function names**: `test_functionName_outcome_optionalContext`

### Contract Structure & Organization

#### File Header

```solidity
// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.29;
```

#### Contract Layout (in order)

1. License identifier
2. Pragma statements
3. Import statements
4. Contract declaration
5. State variables (grouped by visibility)
6. Events
7. Errors
8. Modifiers
9. Constructor/Initializer
10. External functions
11. Public functions
12. Internal functions
13. Private functions

### Documentation Standards

#### NatSpec Requirements

- **All external functions, events, and errors should have complete NatSpec**
- Minimally include `@notice`
- Include `@param` and `@return` for parameters and return values

**Example formatting:**

```solidity
/// @notice Brief description
///
/// @dev Implementation details
///
/// @param paramName Parameter description
///
/// @return returnValue Return value description
```

#### Struct Documentation

```solidity
/// @notice A struct describing an account's position
struct Position {
    /// @dev The unix timestamp (seconds) when position was created
    uint256 created;
    /// @dev The amount of ETH in the position
    uint256 amount;
}
```

### Security Standards

#### Input Validation

- Validate all inputs at function entry
- Check for zero addresses where applicable
- Validate array lengths and bounds
- Ensure numeric inputs are within expected ranges

#### State Management

- Update state before external calls
- Use reentrancy guards where needed
- Avoid state changes after external calls

#### Access Control

- Use OpenZeppelin's access control patterns (`OwnableUpgradeable`)
- Create custom modifiers for complex authorization logic
- Always validate caller permissions before state changes

### Gas Optimization Guidelines

#### Storage

- Pack struct members efficiently (256-bit boundaries)
- Use mappings over arrays when possible for lookups
- Minimize storage writes
- Use `immutable` and `constant` appropriately

#### Function Optimization

- Use `external` visibility when function won't be called internally
- Batch operations when possible
- Avoid unbounded loops
- Cache array lengths in memory

### Protocol-Specific Patterns

#### Campaign Management

- Use status enums for state machine management
- Implement proper state transition validation
- Track balances and allocations separately for audit clarity

#### Attribution & Rewards

- Validate attribution provider authorization
- Implement overattribution protection
- Use precise fee calculations with basis points

#### Publisher Registry

- Generate unique identifiers securely
- Implement chain-specific overrides for multi-chain support
- Validate ref code uniqueness

### Code Quality Checklist

- [ ] License identifier present
- [ ] Pragma version specified
- [ ] Named imports used and ordered alphabetically
- [ ] NatSpec documentation complete
- [ ] Custom errors defined (CapWords style)
- [ ] Events emitted for state changes (past tense)
- [ ] Input validation implemented
- [ ] Access control enforced
- [ ] Gas optimization considered
- [ ] Security patterns followed
- [ ] Tests written and passing
- [ ] Struct packing optimized
- [ ] Assembly avoided unless >25% gas savings

# important-instruction-reminders

Do what has been asked; nothing more, nothing less.
NEVER create files unless they're absolutely necessary for achieving your goal.
ALWAYS prefer editing an existing file to creating a new one.
NEVER proactively create documentation files (\*.md) or README files. Only create documentation files if explicitly requested by the User.

## Testing Guidelines

- If I am telling you to create tests, and things don't work as expected based on README.md, then always let me know
