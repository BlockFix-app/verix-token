// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IVerixDividend {
    event DividendDistributed(uint256 amount, uint256 timestamp);
    event DividendClaimed(address indexed user, uint256 amount);
    event DividendPeriodUpdated(uint256 newPeriod);

    function distributeDividends() external payable;
    function claimDividends() external;
    function withdrawUnclaimedDividends() external;
    
    function setDividendPeriod(uint256 newPeriod) external;
    function pauseDividends() external;
    function unpauseDividends() external;

    function getDividendInfo(address account) external view returns (
        uint256 unclaimedAmount,
        uint256 lastClaimTime,
        uint256 totalClaimed
    );

    function getGlobalDividendInfo() external view returns (
        uint256 totalDistributed,
        uint256 currentPeriod,
        uint256 lastDistributionTime,
        bool isPaused
    );
}
