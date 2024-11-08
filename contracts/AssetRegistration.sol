// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract AssetRegistration {
    struct Asset {
        string manufacturer;
        string model;
        string specifications;
        uint256 warrantyPeriod;
        address owner;
    }

    mapping(uint256 => Asset) public assets;
    uint256 public nextAssetId;

    event AssetRegistered(uint256 indexed assetId, address indexed owner);
    event OwnershipTransferred(uint256 indexed assetId, address indexed newOwner);
    event DetailsUpdated(uint256 indexed assetId, string newDetails);

    function registerAsset(string memory manufacturer, string memory model, string memory specifications, uint256 warrantyPeriod) public {
        uint256 assetId = nextAssetId;
        nextAssetId++;

        assets[assetId] = Asset(manufacturer, model, specifications, warrantyPeriod, msg.sender);
        emit AssetRegistered(assetId, msg.sender);
    }

    function transferOwnership(uint256 assetId, address newOwner) public {
        require(msg.sender == assets[assetId].owner, "Caller is not the asset owner");
        assets[assetId].owner = newOwner;
        emit OwnershipTransferred(assetId, newOwner);
    }

    function updateDetails(uint256 assetId, string memory newSpecifications) public {
        require(msg.sender == assets[assetId].owner, "Caller is not the asset owner");
        assets[assetId].specifications = newSpecifications;
        emit DetailsUpdated(assetId, newSpecifications);
    }
}