// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IVerixGasPool
 * @notice Interface for the gas pool contract that manages gas fee coverage
 */
interface IVerixGasPool {
    /**
     * @dev Struct to define tier configuration
     */
    struct Tier {
        uint256 minTokens;      // Minimum tokens required for tier
        uint256 coveragePercent; // Coverage percentage in basis points (100% = 10000)
        uint256 maxDailyGas;    // Maximum daily gas coverage
    }

    /**
     * @dev Struct to track user gas usage
     */
    struct UserGasUsage {
        uint256 dailyUsed;        // Gas used today
        uint256 lastResetTime;    // Last daily reset timestamp
        uint256 totalLifetimeUsed; // Total gas used lifetime
    }

    // Events
    event GasCovered(address indexed user, uint256 amount, uint256 tierLevel);
    event TierUpdated(address indexed user, uint256 newTier);
    event PoolReplenished(uint256 amount);
    event TierConfigUpdated(uint256 tierId, uint256 minTokens, uint256 coveragePercent);
    event EmergencyWithdraw(address indexed admin, uint256 amount);
    event MinimumBalanceUpdated(uint256 newMinimum);

    /**
     * @notice Updates user's tier based on their token balance
     * @param user Address of the user
     */
    function updateUserTier(address user) external;

    /**
     * @notice Covers gas fees for eligible users
     * @param user Address of the user
     * @param gasAmount Amount of gas to cover
     * @return Amount of gas covered
     */
    function coverGasFee(address user, uint256 gasAmount) external returns (uint256);

    /**
     * @notice Replenishes the gas pool
     */
    function replenishPool() external payable;

    /**
     * @notice Updates tier configuration
     * @param tierId Tier identifier
     * @param minTokens Minimum tokens required
     * @param coveragePercent Coverage percentage in basis points
     * @param maxDailyGas Maximum daily gas coverage
     */
    function updateTier(
        uint256 tierId,
        uint256 minTokens,
        uint256 coveragePercent,
        uint256 maxDailyGas
    ) external;

    /**
     * @notice Gets user's current tier information
     * @param user Address to check
     * @return tier Current tier level
     * @return coveragePercent Current coverage percentage
     * @return maxDaily Maximum daily gas limit
     * @return usedToday Gas used today
     */
    function getUserTierInfo(address user) external view returns (
        uint256 tier,
        uint256 coveragePercent,
        uint256 maxDaily,
        uint256 usedToday
    );

    /**
     * @notice Gets tier configuration
     * @param tierId Tier identifier
     * @return Tier configuration
     */
    function getTier(uint256 tierId) external view returns (Tier memory);

    /**
     * @notice Gets user's gas usage information
     * @param user Address to check
     * @return UserGasUsage structure
     */
    function getUserGasUsage(address user) external view returns (UserGasUsage memory);

    /**
     * @notice Gets pool status information
     * @return current Current pool balance
     * @return minimum Minimum required balance
     * @return totalUsers Total number of users with tiers
     */
    function getPoolStatus() external view returns (
        uint256 current,
        uint256 minimum,
        uint256 totalUsers
    );

    /**
     * @notice Sets minimum pool balance
     * @param newMinimum New minimum balance
     */
    function setMinimumPoolBalance(uint256 newMinimum) external;

    /**
     * @notice Emergency withdrawal of funds
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external;

    /**
     * @notice Pauses the contract
     */
    function pause() external;

    /**
     * @notice Unpauses the contract
     */
    function unpause() external;
}