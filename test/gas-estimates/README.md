# Gas Estimates

## Get Gas Usage

### All tests

```bash
forge test --match-contract AdBatchRewardsTest --gas-report
```

### Specific test functions

```bash
# 1000 events, 1 publisher
forge test --match-test test_batchRewards_1000Events --gas-report

# 1000 events, 10 publishers
forge test --match-test test_batchRewards_1000Events_10Publishers --gas-report

# 1000 events, 1000 unique users (recipient type = 2)  
forge test --match-test test_batchRewards_1000Events_UniqueUsers --gas-report
```

## Calculate USD Cost

1. Get gas from report (look for `reward` function)
2. Get BASE gas price: https://basescan.org/chart/gasprice
3. Get ETH price: any crypto site
4. Formula: `gas_used × gas_price_gwei × eth_price_usd ÷ 1,000,000,000`
