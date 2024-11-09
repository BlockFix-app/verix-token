# Solidity API

## MaintenanceLog

### Contract
MaintenanceLog : contracts/MaintenanceLog.sol

 --- 
### Functions:
### logService

```solidity
function logService(uint256 assetId, string serviceType, string serviceProvider, string partsReplaced) public
```

### getServiceHistory

```solidity
function getServiceHistory(uint256 assetId) public view returns (struct MaintenanceLog.ServiceRecord[])
```

 --- 
### Events:
### ServiceLogged

```solidity
event ServiceLogged(uint256 assetId, uint256 date, string serviceType)
```

