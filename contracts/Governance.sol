// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Governance {
    struct Proposal {
        string description;
        uint256 voteCount;
        bool executed;
    }

    struct Voter {
        bool voted;
        uint256 weight;
    }

    Proposal[] public proposals;
    mapping(address => Voter) public voters;

    event ProposalCreated(uint256 indexed proposalId, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    function createProposal(string memory description) public {
        proposals.push(Proposal({
            description: description,
            voteCount: 0,
            executed: false
        }));
        emit ProposalCreated(proposals.length - 1, description);
    }

    function vote(uint256 proposalId) public {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "Already voted");
        require(proposalId < proposals.length, "Invalid proposal");

        sender.voted = true;
        sender.weight = 1; // Adjust as needed for voting power
        proposals[proposalId].voteCount += sender.weight;

        emit Voted(proposalId, msg.sender, sender.weight);
    }

    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(proposal.voteCount > 0, "Not enough votes");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
        // Implement action to be taken if proposal passes
    }
}