// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract GasFeeCoverage {
    mapping(address => uint256) public holdings;
    mapping(address => uint256) public coverageTiers;

    event TierUpdated(address indexed user, uint256 coverageTier);

    function updateHoldings(address user, uint256 newHoldings) public {
        holdings[user] = newHoldings;
        _updateCoverageTier(user);
    }

    function checkTier(address user) public view returns (uint256) {
        return coverageTiers[user];
    }

    function applyCoverage(uint256 transactionCost, address user) public view returns (uint256) {
        uint256 tier = coverageTiers[user];
        uint256 discount = (transactionCost * tier) / 100;
        return transactionCost - discount;
    }

    function _updateCoverageTier(address user) internal {
        uint256 userHoldings = holdings[user];
        uint256 tier;

        if (userHoldings >= 1000 * 10**18) {
            tier = 100;
        } else if (userHoldings >= 500 * 10**18) {
            tier = 75;
        } else if (userHoldings >= 100 * 10**18) {
            tier = 50;
        } else {
            tier = 0;
        }

        coverageTiers[user] = tier;
        emit TierUpdated(user, tier);
    }
}