// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IVerixToken {
    // Events
    event DividendDistributed(uint256 amount, uint256 timestamp);
    event DividendClaimed(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address proposer, bytes32 proposalHash);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    // Core ERC20 functions
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    // ERC20Permit functions
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    // Dividend functions
    function distributeDividends() external payable;
    function claimDividends() external;
    function unclaimedDividends(address account) external view returns (uint256);
    function lastDividendPerToken(address account) external view returns (uint256);

    // Governance functions
    function createProposal(bytes32 proposalHash) external returns (uint256);
    function castVote(uint256 proposalId, bool support) external;
    function executeProposal(uint256 proposalId) external;
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        bytes32 proposalHash,
        uint256 startTime,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed
    );
    function votingPower(address account) external view returns (uint256);

    // Admin functions
    function pause() external;
    function unpause() external;
}
