// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IVerixGasOracle
 * @notice Interface for the gas oracle contract that manages price feeds and calculations
 */
interface IVerixGasOracle {
    // Events
    event GasPriceUpdated(uint256 newPrice, uint256 timestamp);
    event MaticPriceUpdated(uint256 newPrice, uint256 timestamp);
    event PriceLimitsUpdated(uint256 minPrice, uint256 maxPrice);
    event PriceFeedUpdated(address indexed feed, bool isMaticFeed);
    event PriceStaleThresholdUpdated(uint256 newThreshold);

    /**
     * @notice Updates both MATIC/USD and gas prices
     * @dev Fetches latest prices from Chainlink oracles
     */
    function updatePrices() external;

    /**
     * @notice Calculates gas cost in MATIC for a given gas amount
     * @param gasAmount Amount of gas units
     * @return Gas cost in MATIC (with PRICE_PRECISION decimals)
     */
    function calculateGasCost(uint256 gasAmount) external view returns (uint256);

    /**
     * @notice Converts MATIC amount to USD value
     * @param maticAmount Amount of MATIC to convert
     * @return USD value (with PRICE_PRECISION decimals)
     */
    function maticToUsd(uint256 maticAmount) external view returns (uint256);

    /**
     * @notice Updates price limits
     * @param newMinPrice New minimum gas price (in wei)
     * @param newMaxPrice New maximum gas price (in wei)
     */
    function updatePriceLimits(
        uint256 newMinPrice,
        uint256 newMaxPrice
    ) external;

    /**
     * @notice Gets latest prices and update timestamp
     * @return latestGasPrice Latest gas price in wei
     * @return latestMaticPrice Latest MATIC/USD price
     * @return updateTime Timestamp of last update
     */
    function getLatestPrices() external view returns (
        uint256 latestGasPrice,
        uint256 latestMaticPrice,
        uint256 updateTime
    );

    /**
     * @notice Checks if prices need updating
     * @return True if prices are stale
     */
    function needsUpdate() external view returns (bool);

    /**
     * @notice Gets price feed addresses
     * @return maticUsd MATIC/USD price feed address
     * @return gasWei Gas/Wei price feed address
     */
    function getPriceFeeds() external view returns (
        address maticUsd,
        address gasWei
    );

    /**
     * @notice Gets price limits
     * @return min Minimum gas price
     * @return max Maximum gas price
     */
    function getPriceLimits() external view returns (
        uint256 min,
        uint256 max
    );

    /**
     * @notice Updates price feed address
     * @param newFeed New price feed address
     * @param isMaticFeed True if updating MATIC/USD feed, false for gas price feed
     */
    function updatePriceFeed(
        address newFeed,
        bool isMaticFeed
    ) external;

    /**
     * @notice Updates price staleness threshold
     * @param newThreshold New threshold in seconds
     */
    function updateStaleThreshold(uint256 newThreshold) external;

    /**
     * @notice Gets current staleness threshold
     * @return Threshold in seconds
     */
    function getStaleThreshold() external view returns (uint256);

    /**
     * @notice Checks if a specific price feed is stale
     * @param isMaticFeed True to check MATIC/USD feed, false for gas price feed
     * @return True if price feed is stale
     */
    function isPriceFeedStale(bool isMaticFeed) external view returns (bool);

    /**
     * @notice Emergency pause
     */
    function pause() external;

    /**
     * @notice Unpause
     */
    function unpause() external;

    /**
     * @notice Checks if contract is paused
     * @return True if paused
     */
    function paused() external view returns (bool);
}