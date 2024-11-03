// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title VerixGasPool
 * @notice Manages the gas fee coverage system for Verix token holders
 */
contract VerixGasPool is ReentrancyGuard, AccessControl, Pausable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Tier thresholds and coverage percentages (in basis points, 10000 = 100%)
    struct Tier {
        uint256 minTokens;
        uint256 coveragePercent;
        uint256 maxDailyGas;
    }

    // User gas usage tracking
    struct UserGasUsage {
        uint256 dailyUsed;
        uint256 lastResetTime;
        uint256 totalLifetimeUsed;
    }

    // State variables
    IERC20 public verixToken;
    AggregatorV3Interface public gasPriceOracle;
    
    mapping(uint256 => Tier) public tiers;
    mapping(address => UserGasUsage) public userGasUsage;
    mapping(address => uint256) public userTier;
    
    uint256 public constant BASIC_TIER = 1;
    uint256 public constant STANDARD_TIER = 2;
    uint256 public constant PREMIUM_TIER = 3;
    
    uint256 public poolBalance;
    uint256 public minimumPoolBalance;
    uint256 public constant BASIS_POINTS = 10000;
    
    // Events
    event GasCovered(address indexed user, uint256 amount, uint256 tierLevel);
    event TierUpdated(address indexed user, uint256 newTier);
    event PoolReplenished(uint256 amount);
    event TierConfigUpdated(uint256 tierId, uint256 minTokens, uint256 coveragePercent);
    
    constructor(
        address _verixToken,
        address _gasPriceOracle,
        address _admin
    ) {
        verixToken = IERC20(_verixToken);
        gasPriceOracle = AggregatorV3Interface(_gasPriceOracle);
        
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(ADMIN_ROLE, _admin);
        _setupRole(OPERATOR_ROLE, _admin);
        
        // Initialize tiers
        tiers[BASIC_TIER] = Tier(1000 * 10**18, 5000, 100 * 10**18); // 1000 VRX, 50% coverage
        tiers[STANDARD_TIER] = Tier(5000 * 10**18, 7500, 200 * 10**18); // 5000 VRX, 75% coverage
        tiers[PREMIUM_TIER] = Tier(10000 * 10**18, 10000, 500 * 10**18); // 10000 VRX, 100% coverage
    }
    
    /**
     * @notice Updates user's tier based on their Verix token balance
     * @param user Address of the user
     */
    function updateUserTier(address user) public {
        uint256 balance = verixToken.balanceOf(user);
        uint256 newTier;
        
        if (balance >= tiers[PREMIUM_TIER].minTokens) {
            newTier = PREMIUM_TIER;
        } else if (balance >= tiers[STANDARD_TIER].minTokens) {
            newTier = STANDARD_TIER;
        } else if (balance >= tiers[BASIC_TIER].minTokens) {
            newTier = BASIC_TIER;
        } else {
            newTier = 0;
        }
        
        if (userTier[user] != newTier) {
            userTier[user] = newTier;
            emit TierUpdated(user, newTier);
        }
    }
    
    /**
     * @notice Covers gas fees for eligible users
     * @param user Address of the user
     * @param gasAmount Amount of gas to cover
     */
    function coverGasFee(address user, uint256 gasAmount) 
        external 
        nonReentrant 
        onlyRole(OPERATOR_ROLE) 
        whenNotPaused 
        returns (uint256)
    {
        require(gasAmount > 0, "Invalid gas amount");
        
        // Update user tier
        updateUserTier(user);
        uint256 tier = userTier[user];
        require(tier > 0, "User not eligible for gas coverage");
        
        // Reset daily usage if needed
        if (block.timestamp >= userGasUsage[user].lastResetTime + 1 days) {
            userGasUsage[user].dailyUsed = 0;
            userGasUsage[user].lastResetTime = block.timestamp;
        }
        
        // Check daily limits
        require(
            userGasUsage[user].dailyUsed + gasAmount <= tiers[tier].maxDailyGas,
            "Daily gas limit exceeded"
        );
        
        // Calculate coverage amount
        uint256 coverageAmount = (gasAmount * tiers[tier].coveragePercent) / BASIS_POINTS;
        require(coverageAmount <= poolBalance, "Insufficient pool balance");
        
        // Update state
        poolBalance -= coverageAmount;
        userGasUsage[user].dailyUsed += gasAmount;
        userGasUsage[user].totalLifetimeUsed += coverageAmount;
        
        emit GasCovered(user, coverageAmount, tier);
        return coverageAmount;
    }
    
    /**
     * @notice Replenishes the gas pool
     */
    function replenishPool() external payable onlyRole(ADMIN_ROLE) {
        poolBalance += msg.value;
        emit PoolReplenished(msg.value);
    }
    
    /**
     * @notice Updates tier configuration
     */
    function updateTier(
        uint256 tierId,
        uint256 minTokens,
        uint256 coveragePercent,
        uint256 maxDailyGas
    ) external onlyRole(ADMIN_ROLE) {
        require(tierId > 0 && tierId <= PREMIUM_TIER, "Invalid tier");
        require(coveragePercent <= BASIS_POINTS, "Invalid coverage percentage");
        
        tiers[tierId] = Tier(minTokens, coveragePercent, maxDailyGas);
        emit TierConfigUpdated(tierId, minTokens, coveragePercent);
    }
    
    /**
     * @notice Gets current gas price from oracle
     */
    function getGasPrice() public view returns (uint256) {
        (, int256 price,,,) = gasPriceOracle.latestRoundData();
        return uint256(price);
    }
    
    /**
     * @notice Emergency pause
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause the contract
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}

/**
 * @title VerixGasManager
 * @notice Manages the interaction between users and the gas pool
 */
contract VerixGasManager {
    VerixGasPool public gasPool;
    mapping(address => bool) public authorizedRelayers;
    
    event GasRequested(address indexed user, uint256 amount);
    
    constructor(address _gasPool) {
        gasPool = VerixGasPool(_gasPool);
    }
    
    /**
     * @notice Request gas coverage for a transaction
     */
    function requestGasCoverage(uint256 estimatedGas) external returns (uint256) {
        uint256 covered = gasPool.coverGasFee(msg.sender, estimatedGas);
        emit GasRequested(msg.sender, covered);
        return covered;
    }
}
