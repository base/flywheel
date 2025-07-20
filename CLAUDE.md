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
- Integrates with FlywheelPublisherRegistry for publisher management
- Used for Spindl/Base Ads campaigns

**CommerceCashback.sol** - E-commerce cashback campaigns:

- Direct user rewards for purchases (no publishers involved)
- Integrates with AuthCaptureEscrow for payment verification
- Percentage-based cashback calculation

### Supporting Components

**FlywheelPublisherRegistry.sol** - Publisher management:

- Publisher registration and ref code generation
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

1. Attribution provider calls `flywheel.attribute(campaign, token, attributionData)`
2. Hook validates attribution data and sender permissions
3. Hook returns array of payouts and attribution fee
4. Flywheel accumulates payouts and transfers tokens from campaign
5. Recipients call `distributePayouts()` to claim rewards

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
  - `FlywheelPublisherRegistry.sol` - Publisher management
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
