// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IVerixGasOracle.sol";

/**
 * @title VerixGasOracle
 * @notice Manages gas price data and calculations for the Verix ecosystem
 * @dev Uses Chainlink price feeds for reliable price data
 */
contract VerixGasOracle is IVerixGasOracle, AccessControl, Pausable {
    using ECDSA for bytes32;

    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    
    // Chainlink price feed interfaces
    AggregatorV3Interface public maticUsdPriceFeed;
    AggregatorV3Interface public gasWeiPriceFeed;
    
    // Price storage
    uint256 public constant PRICE_PRECISION = 1e8;
    uint256 public constant PRICE_STALENESS_THRESHOLD = 3600; // 1 hour
    uint256 public lastUpdateTimestamp;
    uint256 public gasPrice;
    uint256 public maticUsdPrice;
    
    // Gas price limits
    uint256 public maxGasPrice;
    uint256 public minGasPrice;
    
    // Events
    event GasPriceUpdated(uint256 newPrice, uint256 timestamp);
    event MaticPriceUpdated(uint256 newPrice, uint256 timestamp);
    event PriceLimitsUpdated(uint256 minPrice, uint256 maxPrice);
    event PriceFeedUpdated(address indexed feed, bool isMaticFeed);
    
    /**
     * @notice Contract constructor
     * @param _maticUsdPriceFeed Chainlink MATIC/USD price feed address
     * @param _gasWeiPriceFeed Chainlink Gas/Wei price feed address
     */
    constructor(
        address _maticUsdPriceFeed,
        address _gasWeiPriceFeed
    ) {
        maticUsdPriceFeed = AggregatorV3Interface(_maticUsdPriceFeed);
        gasWeiPriceFeed = AggregatorV3Interface(_gasWeiPriceFeed);
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ORACLE_UPDATER_ROLE, msg.sender);
        
        // Set default price limits
        minGasPrice = 30 * 10**9; // 30 gwei
        maxGasPrice = 500 * 10**9; // 500 gwei
        
        // Initialize prices
        updatePrices();
    }
    
    /**
     * @notice Updates both MATIC/USD and gas prices
     * @dev Fetches latest prices from Chainlink oracles
     */
    function updatePrices() public override whenNotPaused {
        // Update MATIC/USD price
        (
            uint80 roundId,
            int256 maticPrice,
            ,
            uint256 maticUpdateTime,
            uint80 answeredInRound
        ) = maticUsdPriceFeed.latestRoundData();
        
        require(maticPrice > 0, "Invalid MATIC price");
        require(answeredInRound >= roundId, "Stale MATIC price");
        require(
            block.timestamp - maticUpdateTime <= PRICE_STALENESS_THRESHOLD,
            "MATIC price too old"
        );
        
        maticUsdPrice = uint256(maticPrice);
        
        // Update gas price in Wei
        (
            roundId,
            int256 gasWeiPrice,
            ,
            uint256 gasUpdateTime,
            answeredInRound
        ) = gasWeiPriceFeed.latestRoundData();
        
        require(gasWeiPrice > 0, "Invalid gas price");
        require(answeredInRound >= roundId, "Stale gas price");
        require(
            block.timestamp - gasUpdateTime <= PRICE_STALENESS_THRESHOLD,
            "Gas price too old"
        );
        
        uint256 newGasPrice = uint256(gasWeiPrice);
        require(
            newGasPrice >= minGasPrice && newGasPrice <= maxGasPrice,
            "Gas price out of bounds"
        );
        
        gasPrice = newGasPrice;
        lastUpdateTimestamp = block.timestamp;
        
        emit MaticPriceUpdated(maticUsdPrice, block.timestamp);
        emit GasPriceUpdated(gasPrice, block.timestamp);
    }
    
    /**
     * @notice Calculates gas cost in MATIC for a given gas amount
     * @param gasAmount Amount of gas units
     * @return Gas cost in MATIC (with PRICE_PRECISION decimals)
     */
    function calculateGasCost(uint256 gasAmount) 
        public 
        view 
        override 
        returns (uint256) 
    {
        require(
            block.timestamp - lastUpdateTimestamp <= PRICE_STALENESS_THRESHOLD,
            "Prices are stale"
        );
        return (gasAmount * gasPrice) / PRICE_PRECISION;
    }
    
    /**
     * @notice Converts MATIC amount to USD value
     * @param maticAmount Amount of MATIC to convert
     * @return USD value (with PRICE_PRECISION decimals)
     */
    function maticToUsd(uint256 maticAmount) 
        public 
        view 
        override 
        returns (uint256) 
    {
        require(
            block.timestamp - lastUpdateTimestamp <= PRICE_STALENESS_THRESHOLD,
            "Prices are stale"
        );
        return (maticAmount * maticUsdPrice) / PRICE_PRECISION;
    }
    
    /**
     * @notice Updates price feed addresses
     * @param newFeed New price feed address
     * @param isMaticFeed True if updating MATIC/USD feed, false for gas price feed
     */
    function updatePriceFeed(address newFeed, bool isMaticFeed) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newFeed != address(0), "Invalid feed address");
        
        if (isMaticFeed) {
            maticUsdPriceFeed = AggregatorV3Interface(newFeed);
        } else {
            gasWeiPriceFeed = AggregatorV3Interface(newFeed);
        }
        
        emit PriceFeedUpdated(newFeed, isMaticFeed);
    }
    
    /**
     * @notice Updates gas price limits
     * @param newMinPrice New minimum gas price (in wei)
     * @param newMaxPrice New maximum gas price (in wei)
     */
    function updatePriceLimits(uint256 newMinPrice, uint256 newMaxPrice) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newMinPrice < newMaxPrice, "Invalid price range");
        require(newMinPrice > 0, "Min price must be > 0");
        
        minGasPrice = newMinPrice;
        maxGasPrice = newMaxPrice;
        
        emit PriceLimitsUpdated(newMinPrice, newMaxPrice);
    }
    
    /**
     * @notice Gets latest gas and MATIC prices
     * @return Latest gas price in wei
     * @return Latest MATIC/USD price
     * @return Timestamp of last update
     */
    function getLatestPrices() 
        external 
        view 
        returns (
            uint256 latestGasPrice,
            uint256 latestMaticPrice,
            uint256 updateTime
        ) 
    {
        return (gasPrice, maticUsdPrice, lastUpdateTimestamp);
    }
    
    /**
     * @notice Checks if prices need updating
     * @return True if prices are stale
     */
    function needsUpdate() external view returns (bool) {
        return block.timestamp - lastUpdateTimestamp > PRICE_STALENESS_THRESHOLD;
    }
    
    /**
     * @notice Emergency pause
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
