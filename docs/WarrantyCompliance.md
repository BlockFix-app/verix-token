# Solidity API

## WarrantyCompliance

### Contract
WarrantyCompliance : contracts/WarrantyCompliance.sol

 --- 
### Functions:
### checkWarrantyStatus

```solidity
function checkWarrantyStatus(uint256 assetId) public view returns (bool, uint256)
```

### updateWarranty

```solidity
function updateWarranty(uint256 assetId, bool isUnderWarranty, uint256 newExpiryDate) public
```

 --- 
### Events:
### WarrantyUpdated

```solidity
event WarrantyUpdated(uint256 assetId, bool isUnderWarranty, uint256 expiryDate)
```

