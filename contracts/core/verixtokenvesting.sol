// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/IVerixTokenVesting.sol";

/**
 * @title VerixTokenVesting
 * @notice Handles token vesting for team, advisors, and partners with configurable schedules
 * @dev Supports cliff periods, linear vesting, and revocable schedules
 */
contract VerixTokenVesting is IVerixTokenVesting, AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes32 public constant VESTING_ADMIN_ROLE = keccak256("VESTING_ADMIN_ROLE");
    
    // Verix token contract
    IERC20 public immutable verixToken;
    
    struct VestingSchedule {
        uint256 totalAmount;      // Total amount of tokens to be vested
        uint256 startTime;        // Start time of the vesting period
        uint256 cliffDuration;    // Duration of the cliff period
        uint256 duration;         // Total duration of vesting
        uint256 releasedAmount;   // Amount of tokens released so far
        bool revocable;           // Whether the vesting is revocable by admin
        bool revoked;             // Whether the vesting has been revoked
        uint256 lastClaimTime;    // Last time tokens were claimed
        VestingType vestingType;  // Type of vesting schedule
    }
    
    // Mapping from beneficiary to vesting schedule
    mapping(address => VestingSchedule) public vestingSchedules;
    
    // Vesting schedule counts and totals
    uint256 public totalVestingCount;
    uint256 public totalVestedAmount;
    uint256 public totalReleasedAmount;
    
    constructor(address _verixToken) {
        require(_verixToken != address(0), "Invalid token address");
        verixToken = IERC20(_verixToken);
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(VESTING_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice Creates a new vesting schedule
     * @param beneficiary Address that will receive the vested tokens
     * @param totalAmount Total amount of tokens to be vested
     * @param startTime Start timestamp of the vesting schedule
     * @param cliffDuration Duration of the cliff period in seconds
     * @param duration Total duration of the vesting period in seconds
     * @param vestingType Type of vesting schedule (Linear, Stepped, etc.)
     * @param revocable Whether the schedule can be revoked by admin
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 duration,
        VestingType vestingType,
        bool revocable
    ) external override onlyRole(VESTING_ADMIN_ROLE) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Schedule exists");
        require(totalAmount > 0, "Amount must be > 0");
        require(duration > 0, "Duration must be > 0");
        require(duration > cliffDuration, "Invalid cliff");
        require(startTime >= block.timestamp, "Start must be future");
        
        // Check token allowance and balance
        require(
            verixToken.allowance(msg.sender, address(this)) >= totalAmount,
            "Insufficient allowance"
        );
        require(
            verixToken.balanceOf(msg.sender) >= totalAmount,
            "Insufficient balance"
        );
        
        // Create vesting schedule
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            startTime: startTime,
            cliffDuration: cliffDuration,
            duration: duration,
            releasedAmount: 0,
            revocable: revocable,
            revoked: false,
            lastClaimTime: startTime,
            vestingType: vestingType
        });
        
        // Transfer tokens to contract
        verixToken.safeTransferFrom(msg.sender, address(this), totalAmount);
        
        // Update totals
        totalVestingCount = totalVestingCount.add(1);
        totalVestedAmount = totalVestedAmount.add(totalAmount);
        
        emit VestingScheduleCreated(
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            duration,
            vestingType
        );
    }
    
    /**
     * @notice Allows beneficiary to release their vested tokens
     * @dev Tokens are released according to the vesting schedule
     */
    function release() external override nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Schedule revoked");
        
        uint256 releasableAmount = _getReleasableAmount(schedule);
        require(releasableAmount > 0, "No tokens to release");
        
        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
        schedule.lastClaimTime = block.timestamp;
        totalReleasedAmount = totalReleasedAmount.add(releasableAmount);
        
        verixToken.safeTransfer(msg.sender, releasableAmount);
        
        emit TokensReleased(msg.sender, releasableAmount);
    }
    
    /**
     * @notice Revokes a revocable vesting schedule
     * @param beneficiary Address of the beneficiary whose schedule is being revoked
     */
    function revoke(address beneficiary) 
        external 
        override
        onlyRole(VESTING_ADMIN_ROLE) 
    {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");
        
        // Calculate and release vested amount
        uint256 vestedAmount = _getVestedAmount(schedule);
        uint256 unreleased = vestedAmount.sub(schedule.releasedAmount);
        
        if (unreleased > 0) {
            schedule.releasedAmount = schedule.releasedAmount.add(unreleased);
            totalReleasedAmount = totalReleasedAmount.add(unreleased);
            verixToken.safeTransfer(beneficiary, unreleased);
            emit TokensReleased(beneficiary, unreleased);
        }
        
        // Return unvested tokens to admin
        uint256 remainingAmount = schedule.totalAmount.sub(vestedAmount);
        if (remainingAmount > 0) {
            totalVestedAmount = totalVestedAmount.sub(remainingAmount);
            verixToken.safeTransfer(msg.sender, remainingAmount);
        }
        
        schedule.revoked = true;
        emit VestingRevoked(beneficiary, remainingAmount);
    }
    
    /**
     * @notice Gets the amount of tokens that can be released
     * @param schedule The vesting schedule to check
     * @return The amount of releasable tokens
     */
    function _getReleasableAmount(VestingSchedule storage schedule)
        private
        view
        returns (uint256)
    {
        if (block.timestamp < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }
        
        uint256 vestedAmount = _getVestedAmount(schedule);
        return vestedAmount.sub(schedule.releasedAmount);
    }
    
    /**
     * @notice Calculates vested amount based on vesting type and schedule
     * @param schedule The vesting schedule to calculate for
     * @return The total vested amount
     */
    function _getVestedAmount(VestingSchedule storage schedule)
        private
        view
        returns (uint256)
    {
        if (block.timestamp < schedule.startTime) {
            return 0;
        }
        
        if (block.timestamp >= schedule.startTime.add(schedule.duration)) {
            return schedule.totalAmount;
        }
        
        uint256 timeFromStart = block.timestamp.sub(schedule.startTime);
        
        if (schedule.vestingType == VestingType.Linear) {
            return schedule.totalAmount.mul(timeFromStart).div(schedule.duration);
        } else if (schedule.vestingType == VestingType.Stepped) {
            // Steps are calculated quarterly (4 steps per year)
            uint256 stepDuration = schedule.duration.div(4);
            uint256 currentStep = timeFromStart.div(stepDuration);
            return schedule.totalAmount.mul(currentStep).div(4);
        }
        
        return 0;
    }
    
    /**
     * @notice Gets detailed vesting information for a beneficiary
     * @param beneficiary Address to check
     * @return Full vesting schedule information
     */
    function getVestingSchedule(address beneficiary)
        external
        view
        override
        returns (
            uint256 totalAmount,
            uint256 startTime,
            uint256 cliffDuration,
            uint256 duration,
            uint256 releasedAmount,
            bool revocable,
            bool revoked,
            uint256 releasableAmount,
            VestingType vestingType
        )
    {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.duration,
            schedule.releasedAmount,
            schedule.revocable,
            schedule.revoked,
            _getReleasableAmount(schedule),
            schedule.vestingType
        );
    }
    
    /**
     * @notice Emergency function to recover stuck tokens
     * @param token The token to recover
     * @param amount Amount to recover
     */
    function recoverToken(address token, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(token != address(verixToken), "Cannot recover vesting token");
        IERC20(token).safeTransfer(msg.sender, amount);
        emit TokenRecovered(token, amount);
    }
}
