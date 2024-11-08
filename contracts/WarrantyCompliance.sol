// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract WarrantyCompliance {
    struct Warranty {
        bool isUnderWarranty;
        uint256 expiryDate;
    }

    mapping(uint256 => Warranty) public warranties;

    event WarrantyUpdated(uint256 indexed assetId, bool isUnderWarranty, uint256 expiryDate);

    function checkWarrantyStatus(uint256 assetId) public view returns (bool, uint256) {
        return (warranties[assetId].isUnderWarranty, warranties[assetId].expiryDate);
    }

    function updateWarranty(uint256 assetId, bool isUnderWarranty, uint256 newExpiryDate) public {
        warranties[assetId] = Warranty(isUnderWarranty, newExpiryDate);
        emit WarrantyUpdated(assetId, isUnderWarranty, newExpiryDate);
    }
}