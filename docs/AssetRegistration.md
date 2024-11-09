# Solidity API

## AssetRegistration

### Contract
AssetRegistration : contracts/AssetRegistration.sol

 --- 
### Functions:
### registerAsset

```solidity
function registerAsset(string manufacturer, string model, string specifications, uint256 warrantyPeriod) public
```

### transferOwnership

```solidity
function transferOwnership(uint256 assetId, address newOwner) public
```

### updateDetails

```solidity
function updateDetails(uint256 assetId, string newSpecifications) public
```

 --- 
### Events:
### AssetRegistered

```solidity
event AssetRegistered(uint256 assetId, address owner)
```

### OwnershipTransferred

```solidity
event OwnershipTransferred(uint256 assetId, address newOwner)
```

### DetailsUpdated

```solidity
event DetailsUpdated(uint256 assetId, string newDetails)
```

