# Naming Conventions

## Contract Names

Use the exact contract name as defined in the Solidity files:

### ✅ Correct Terms

- **BuilderCodes** - The contract for managing publisher referral codes and payout addresses
- **AdConversion** - Hook for performance marketing campaigns
- **CashbackRewards** - Hook for e-commerce cashback campaigns
- **SimpleRewards** - Hook for basic reward distribution

### ❌ Avoid These Terms

- ~~Publisher Registry~~ → Use **BuilderCodes**
- ~~PublisherRegistry~~ → Use **BuilderCodes**
- ~~CommerceCashback~~ → Use **CashbackRewards**
- ~~FlywheelCampaigns~~ → Deprecated, no longer exists
- ~~Monolithic~~ → Remove references to old architecture

## Documentation Standards

- Always use the exact contract name when referencing contracts
- Use proper capitalization and spacing
- Avoid abbreviated or informal names in user-facing documentation
- Contract variables in code can use camelCase (e.g., `builderCodes`)
