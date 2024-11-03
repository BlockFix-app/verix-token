// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IVerixTokenVesting
 * @notice Interface for the VerixTokenVesting contract
 */
interface IVerixTokenVesting {
    // Enums
    enum VestingType {
        Linear,     // Linear vesting over time
        Stepped     // Stepped vesting (quarterly)
    }

    // Events
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 duration,
        VestingType vestingType
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 remainingAmount);
    event TokenRecovered(address indexed token, uint256 amount);

    // Functions
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 duration,
        VestingType vestingType,
        bool revocable
    ) external;

    function release() external;

    function revoke(address beneficiary) external;

    function getVestingSchedule(address beneficiary) 
        external 
        view 
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
        );
}
