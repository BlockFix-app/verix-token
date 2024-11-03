// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title VerixDividend
 * @notice Manages dividend distribution for Verix token holders
 * @dev Implements a dividend distribution system with snapshots and claims
 */
contract VerixDividend is ReentrancyGuard, Pausable, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant DIVIDEND_MANAGER_ROLE = keccak256("DIVIDEND_MANAGER_ROLE");
    
    IERC20 public immutable verixToken;
    
    struct DividendCycle {
        uint256 totalDividends;
        uint256 totalShares;
        uint256 dividendPerShare;
        uint256 timestamp;
        bool finalized;
    }
    
    struct UserInfo {
        uint256 lastClaimedCycle;
        uint256 unclaimedDividends;
        uint256 totalClaimed;
        uint256 lastShareBalance;
    }
    
    // Current dividend cycle
    uint256 public currentCycleId;
    // Mapping from cycle ID to dividend information
    mapping(uint256 => DividendCycle) public dividendCycles;
    // Mapping from user address to dividend information
    mapping(address => UserInfo) public userInfo;
    
    // Minimum time between dividend distributions
    uint256 public constant MIN_DISTRIBUTION_INTERVAL = 1 days;
    // Maximum dividend cycles that can be claimed in one transaction
    uint256 public constant MAX_CLAIM_CYCLES = 50;
    
    // Events
    event DividendDistributed(uint256 indexed cycleId, uint256 amount);
    event DividendClaimed(address indexed user, uint256 amount, uint256[] cycles);
    event CyclePeriodUpdated(uint256 newPeriod);
    
    /**
     * @notice Contract constructor
     * @param _verixToken Address of the Verix token contract
     * @param _admin Address that will have admin role
     */
    constructor(address _verixToken, address _admin) {
        require(_verixToken != address(0), "Invalid token address");
        require(_admin != address(0), "Invalid admin address");
        
        verixToken = IERC20(_verixToken);
        
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(DIVIDEND_MANAGER_ROLE, _admin);
        
        // Initialize first cycle
        currentCycleId = 1;
        dividendCycles[currentCycleId].timestamp = block.timestamp;
    }
    
    /**
     * @notice Distributes dividends for the current cycle
     * @dev Must send ETH along with the transaction
     */
    function distributeDividends() 
        external 
        payable 
        nonReentrant 
        onlyRole(DIVIDEND_MANAGER_ROLE) 
        whenNotPaused 
    {
        require(msg.value > 0, "No dividends to distribute");
        require(
            block.timestamp >= dividendCycles[currentCycleId].timestamp + MIN_DISTRIBUTION_INTERVAL,
            "Distribution too frequent"
        );
        
        DividendCycle storage cycle = dividendCycles[currentCycleId];
        require(!cycle.finalized, "Cycle already finalized");
        
        // Get total shares (token supply)
        uint256 totalShares = verixToken.totalSupply();
        require(totalShares > 0, "No shares exist");
        
        // Calculate dividend per share
        cycle.totalDividends = cycle.totalDividends.add(msg.value);
        cycle.totalShares = totalShares;
        cycle.dividendPerShare = cycle.totalDividends.mul(1e18).div(totalShares);
        cycle.finalized = true;
        
        // Start new cycle
        currentCycleId = currentCycleId.add(1);
        dividendCycles[currentCycleId].timestamp = block.timestamp;
        
        emit DividendDistributed(currentCycleId.sub(1), msg.value);
    }
    
    /**
     * @notice Claims dividends for a user
     * @param maxCycles Maximum number of cycles to claim
     */
    function claimDividends(uint256 maxCycles) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(maxCycles > 0 && maxCycles <= MAX_CLAIM_CYCLES, "Invalid cycles");
        
        address user = msg.sender;
        using EnumerableSet for EnumerableSet.UintSet;
        EnumerableSet.UintSet private claimedCycles;
        uint256[] memory claimedCycles = new uint256[](maxCycles);
        uint256 claimedCount = 0;
        
        // Start from last claimed cycle + 1
        uint256 startCycle = info.lastClaimedCycle.add(1);
        uint256 endCycle = min(currentCycleId, startCycle.add(maxCycles));
        
        for (uint256 cycleId = startCycle; cycleId < endCycle; cycleId++) {
            DividendCycle storage cycle = dividendCycles[cycleId];
            if (!cycle.finalized) break;
            
            uint256 shareBalance = verixToken.balanceOf(user);
            uint256 cycleDividends = shareBalance.mul(cycle.dividendPerShare).div(1e18);
            
            if (cycleDividends > 0) {
                unclaimedAmount = unclaimedAmount.add(cycleDividends);
                claimedCycles[claimedCount] = cycleId;
                claimedCount++;
            }
info.lastClaimedCycle = cycleId;
        }
        
        require(unclaimedAmount > 0, "No dividends to claim");
        
        // Update user info
        info.totalClaimed = info.totalClaimed.add(unclaimedAmount);
        info.lastShareBalance = verixToken.balanceOf(user);
        // Check contract balance and transfer dividends
        require(address(this).balance >= unclaimedAmount, "Insufficient contract balance");
        (bool success, ) = user.call{value: unclaimedAmount}("");
        require(success, "Transfer failed");
        require(success, "Transfer failed");
        
        // Trim claimed cycles array to actual size
        uint256[] memory finalClaimedCycles = new uint256[](claimedCount);
        for (uint256 i = 0; i < claimedCount; i++) {
            finalClaimedCycles[i] = claimedCycles[i];
        }
        
        emit DividendClaimed(user, unclaimedAmount, finalClaimedCycles);
    }
    
    /**
     * @notice Gets unclaimed dividends for a user
     * @param user Address of the user
     * @return unclaimedAmount Total unclaimed dividends
     * @return cycles Array of unclaimed cycle IDs
     */
    function getUnclaimedDividends(address user)
        external
        view
        returns (uint256 unclaimedAmount, uint256[] memory cycles)
    {
        UserInfo storage info = userInfo[user];
        uint256 startCycle = info.lastClaimedCycle.add(1);
        uint256 cycleCount = 0;
        
        // First pass: count valid cycles
        for (uint256 cycleId = startCycle; cycleId < currentCycleId; cycleId++) {
            DividendCycle storage cycle = dividendCycles[cycleId];
            if (!cycle.finalized) break;
            
            uint256 shareBalance = verixToken.balanceOf(user);
            uint256 cycleDividends = shareBalance.mul(cycle.dividendPerShare).div(1e18);
            
            if (cycleDividends > 0) {
                unclaimedAmount = unclaimedAmount.add(cycleDividends);
                cycleCount++;
            }
        }
        
        // Second pass: populate cycles array
        cycles = new uint256[](cycleCount);
        uint256 index = 0;
        for (uint256 cycleId = startCycle; cycleId < currentCycleId; cycleId++) {
            DividendCycle storage cycle = dividendCycles[cycleId];
            if (!cycle.finalized) break;
            
            uint256 shareBalance = verixToken.balanceOf(user);
            uint256 cycleDividends = shareBalance.mul(cycle.dividendPerShare).div(1e18);
            
            if (cycleDividends > 0) {
                cycles[index] = cycleId;
                index++;
            }
        }
    }
    
    /**
     * @notice Gets dividend cycle information
     * @param cycleId ID of the cycle
     * @return totalDividends Total dividends distributed in the cycle
     * @return totalShares Total shares at time of distribution
     * @return dividendPerShare Dividend amount per share
     * @return timestamp Timestamp of the cycle
     * @return finalized Whether the cycle is finalized
     */
    function getDividendCycle(uint256 cycleId)
        external
        view
        returns (
            uint256 totalDividends,
            uint256 totalShares,
            uint256 dividendPerShare,
            uint256 timestamp,
            bool finalized
        )
    {
        DividendCycle storage cycle = dividendCycles[cycleId];
        return (
            cycle.totalDividends,
            cycle.totalShares,
            cycle.dividendPerShare,
            cycle.timestamp,
            cycle.finalized
        );
    }
    
    /**
     * @notice Gets user dividend information
     * @param user Address of the user
     * @return lastClaimedCycle Last claimed cycle
     * @return totalClaimed Total amount claimed
     * @return lastShareBalance Last recorded share balance
     */
    function getUserInfo(address user)
        external
        view
        returns (
            uint256 lastClaimedCycle,
            uint256 totalClaimed,
            uint256 lastShareBalance
        )
    {
        UserInfo storage info = userInfo[user];
        return (
            info.lastClaimedCycle,
            info.totalClaimed,
            info.lastShareBalance
        );
    }
    function withdrawUnclaimedDividends(uint256 amount)
        external
        nonReentrant
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(amount <= address(this).balance, "Insufficient balance");
        uint256 balanceBefore = address(this).balance;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        require(address(this).balance == balanceBefore - amount, "Reentrancy detected");
    }
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @notice Pauses dividend distributions and claims
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpauses dividend distributions and claims
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @notice Helper function to get minimum of two numbers
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    /**
     * @notice Required for receiving ETH
     */
    receive() external payable {
        // Accept ETH transfers
    }
}
