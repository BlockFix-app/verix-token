// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IVerixGovernor {
    struct ProposalVote {
        uint256 forVotes;
        uint256 againstVotes;
        mapping(address => bool) hasVoted;
    }

    event ProposalCreated(
        uint256 indexed proposalId,
        address proposer,
        string description,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock
    );

    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support,
        uint256 weight
    );

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external returns (uint256);

    function cancel(uint256 proposalId) external;

    function castVote(uint256 proposalId, bool support) external returns (uint256);
    
    function castVoteWithReason(
        uint256 proposalId,
        bool support,
        string calldata reason
    ) external returns (uint256);

    function getProposalState(uint256 proposalId) external view returns (uint8);
    
    function proposalVotes(uint256 proposalId) external view returns (
        uint256 forVotes,
        uint256 againstVotes
    );

    function quorum() external view returns (uint256);
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
}
