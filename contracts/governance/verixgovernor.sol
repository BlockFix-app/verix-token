// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

/**
 * @title VerixGovernor
 * @notice Governance contract for the Verix ecosystem with configurable voting parameters
 * @dev Extends OpenZeppelin's Governor contract with additional features
 */
contract VerixGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    // Events
    event ProposalThresholdChanged(uint256 oldThreshold, uint256 newThreshold);
    event VotingDelayChanged(uint256 oldDelay, uint256 newDelay);
    event VotingPeriodChanged(uint256 oldPeriod, uint256 newPeriod);
    event QuorumChanged(uint256 oldQuorum, uint256 newQuorum);
    event ProposalTagged(uint256 indexed proposalId, bytes32 indexed tag);

    // Proposal tags for categorization
    mapping(uint256 => bytes32) public proposalTags;
    
    // Proposal descriptions
    mapping(uint256 => string) public proposalDescriptions;

    /**
     * @notice Contract constructor
     * @param _token The ERC20Votes token used for governance
     * @param _timelock The timelock controller used for governance
     * @param _votingDelay Initial voting delay
     * @param _votingPeriod Initial voting period
     * @param _proposalThreshold Initial proposal threshold
     * @param _quorumPercentage Initial quorum percentage
     */
    constructor(
        IVotes _token,
        TimelockController _timelock,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _proposalThreshold,
        uint256 _quorumPercentage
    )
        Governor("VerixGovernor")
        GovernorSettings(
            _votingDelay,
            _votingPeriod,
            _proposalThreshold
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(_quorumPercentage)
        GovernorTimelockControl(_timelock)
    {}

    /**
     * @notice Creates a new proposal with a tag
     * @param targets Target addresses for proposal calls
     * @param values ETH values for proposal calls
     * @param calldatas Function calldatas for proposal calls
     * @param description Proposal description
     * @param tag Proposal category tag
     */
    function proposeWithTag(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        bytes32 tag
    ) public virtual returns (uint256) {
        uint256 proposalId = propose(targets, values, calldatas, description);
        proposalTags[proposalId] = tag;
        proposalDescriptions[proposalId] = description;
        emit ProposalTagged(proposalId, tag);
        return proposalId;
    }

    /**
     * @notice Updates the proposal threshold
     * @param newThreshold New threshold for proposal creation
     */
    function updateProposalThreshold(uint256 newThreshold) 
        external 
        onlyGovernance 
    {
        uint256 oldThreshold = proposalThreshold();
        _setProposalThreshold(newThreshold);
        emit ProposalThresholdChanged(oldThreshold, newThreshold);
    }

    /**
     * @notice Updates the voting delay
     * @param newVotingDelay New delay before voting starts
     */
    function updateVotingDelay(uint256 newVotingDelay) 
        external 
        onlyGovernance 
    {
        uint256 oldDelay = votingDelay();
        _setVotingDelay(newVotingDelay);
        emit VotingDelayChanged(oldDelay, newVotingDelay);
    }

    /**
     * @notice Updates the voting period
     * @param newVotingPeriod New period for voting
     */
    function updateVotingPeriod(uint256 newVotingPeriod) 
        external 
        onlyGovernance 
    {
        uint256 oldPeriod = votingPeriod();
        _setVotingPeriod(newVotingPeriod);
        emit VotingPeriodChanged(oldPeriod, newVotingPeriod);
    }

    /**
     * @notice Updates the quorum percentage
     * @param newQuorumNumerator New quorum numerator (denominator is 100)
     */
    function updateQuorumNumerator(uint256 newQuorumNumerator) 
        external 
        onlyGovernance 
    {
        uint256 oldQuorum = quorumNumerator();
        _updateQuorumNumerator(newQuorumNumerator);
        emit QuorumChanged(oldQuorum, newQuorumNumerator);
    }

    /**
     * @notice Gets detailed information about a proposal
     * @param proposalId The ID of the proposal
     * @return executed Whether the proposal has been executed
     * @return canceled Whether the proposal has been canceled
     * @return tag The proposal's category tag
     * @return description The proposal's description
     * @return proposer The address that created the proposal
     * @return voteStart The timestamp when voting starts
     * @return voteEnd The timestamp when voting ends
     * @return forVotes The number of votes in favor
     * @return againstVotes The number of votes against
     * @return abstainVotes The number of abstain votes
     */
    function getProposalDetails(uint256 proposalId)
        external
        view
        returns (
            bool executed,
            bool canceled,
            bytes32 tag,
            string memory description,
            address proposer,
            uint256 voteStart,
            uint256 voteEnd,
            uint256 forVotes,
            uint256 againstVotes,
            uint256 abstainVotes
        )
    {
        ProposalState status = state(proposalId);
        executed = (status == ProposalState.Executed);
        canceled = (status == ProposalState.Canceled);
        tag = proposalTags[proposalId];
        description = proposalDescriptions[proposalId];
        
        ProposalCore memory proposal = _proposals[proposalId];
        proposer = proposal.proposer;
        voteStart = proposal.voteStart.getDeadline();
        voteEnd = proposal.voteEnd.getDeadline();

        (forVotes, againstVotes, abstainVotes) = proposalVotes(proposalId);
    }

    // The following functions are overrides required by Solidity

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
        public
        override(Governor, IGovernor)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
