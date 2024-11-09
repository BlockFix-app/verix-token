# Solidity API

## Governance

### Contract
Governance : contracts/Governance.sol

 --- 
### Functions:
### createProposal

```solidity
function createProposal(string description) public
```

### vote

```solidity
function vote(uint256 proposalId) public
```

### executeProposal

```solidity
function executeProposal(uint256 proposalId) public
```

 --- 
### Events:
### ProposalCreated

```solidity
event ProposalCreated(uint256 proposalId, string description)
```

### Voted

```solidity
event Voted(uint256 proposalId, address voter, uint256 weight)
```

### ProposalExecuted

```solidity
event ProposalExecuted(uint256 proposalId)
```

