// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Staking {
    mapping(address => uint256) public stakedTokens;
    mapping(address => uint256) public rewards;

    event TokensStaked(address indexed staker, uint256 amount);
    event TokensUnstaked(address indexed staker, uint256 amount);

    function stakeTokens(uint256 amount) public {
        // Logic for staking tokens
        stakedTokens[msg.sender] += amount;
        // Placeholder for reward calculation
        _calculateRewards(msg.sender);

        emit TokensStaked(msg.sender, amount);
    }

    function unstakeTokens(uint256 amount) public {
        require(stakedTokens[msg.sender] >= amount, "Insufficient staked tokens");

        stakedTokens[msg.sender] -= amount;
        _calculateRewards(msg.sender); // Adjust rewards accordingly

        emit TokensUnstaked(msg.sender, amount);
    }

    function calculateRewards(address staker) public view returns (uint256) {
        // Placeholder for reward logic
        return rewards[staker];
    }

    function _calculateRewards(address staker) internal {
        // Example placeholder for calculating rewards based on staking
        rewards[staker] = stakedTokens[staker] / 100;
    }
}