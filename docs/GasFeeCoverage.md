# Solidity API

## GasFeeCoverage

### Contract
GasFeeCoverage : contracts/GasFeeCoverage.sol

 --- 
### Functions:
### updateHoldings

```solidity
function updateHoldings(address user, uint256 newHoldings) public
```

### checkTier

```solidity
function checkTier(address user) public view returns (uint256)
```

### applyCoverage

```solidity
function applyCoverage(uint256 transactionCost, address user) public view returns (uint256)
```

### _updateCoverageTier

```solidity
function _updateCoverageTier(address user) internal
```

 --- 
### Events:
### TierUpdated

```solidity
event TierUpdated(address user, uint256 coverageTier)
```

