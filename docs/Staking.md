# Solidity API

## Staking

### Contract
Staking : contracts/Staking.sol

 --- 
### Functions:
### stakeTokens

```solidity
function stakeTokens(uint256 amount) public
```

### unstakeTokens

```solidity
function unstakeTokens(uint256 amount) public
```

### calculateRewards

```solidity
function calculateRewards(address staker) public view returns (uint256)
```

### _calculateRewards

```solidity
function _calculateRewards(address staker) internal
```

 --- 
### Events:
### TokensStaked

```solidity
event TokensStaked(address staker, uint256 amount)
```

### TokensUnstaked

```solidity
event TokensUnstaked(address staker, uint256 amount)
```

