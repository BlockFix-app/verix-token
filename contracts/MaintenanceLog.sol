// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MaintenanceLog {
    struct ServiceRecord {
        uint256 date;
        string serviceType;
        string serviceProvider;
        string partsReplaced;
    }

    mapping(uint256 => ServiceRecord[]) public serviceHistory;

    event ServiceLogged(uint256 indexed assetId, uint256 date, string serviceType);

    function logService(uint256 assetId, string memory serviceType, string memory serviceProvider, string memory partsReplaced) public {
        serviceHistory[assetId].push(ServiceRecord(block.timestamp, serviceType, serviceProvider, partsReplaced));
        emit ServiceLogged(assetId, block.timestamp, serviceType);
    }

    function getServiceHistory(uint256 assetId) public view returns (ServiceRecord[] memory) {
        return serviceHistory[assetId];
    }
}