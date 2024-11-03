# Verix Token System Documentation

## Table of Contents
1. [Token Overview](#token-overview)
2. [Contract Architecture](#contract-architecture)
3. [Core Functionality](#core-functionality)
4. [Dividend System](#dividend-system)
5. [Governance System](#governance-system)
6. [Vesting System](#vesting-system)
7. [Security Features](#security-features)
8. [Role Management](#role-management)
9. [Integration Guide](#integration-guide)
10. [Error Handling](#error-handling)

## 1. Token Overview

### Purpose
The Verix Token (VRX) is a comprehensive ERC20 token implementation that includes dividend distribution, governance capabilities, and vesting functionalities. It's designed to serve as the core token for the Verix ecosystem on the Polygon network.

### Key Features
- ERC20 compliance with EIP-2612 permit functionality
- Automated dividend distribution system
- Governance with proposal and voting mechanisms
- Token vesting with configurable schedules
- Role-based access control
- Emergency pause functionality

### Technical Specifications
- Token Name: Verix Token
- Symbol: VRX
- Decimals: 18
- Initial Supply: 1,000,000,000 tokens
- Network: Polygon

## 2. Contract Architecture

### VerixToken Contract
```solidity
contract VerixToken is ERC20Permit, Pausable, AccessControl, ReentrancyGuard {
    // Core token functionality
    // Dividend system
    // Governance system
    // Administrative functions
}
```

### VerixTokenVesting Contract
```solidity
contract VerixTokenVesting is AccessControl, ReentrancyGuard {
    // Vesting schedule management
    // Token release functionality
    // Administrative controls
}
```

## 3. Core Functionality

### Token Transfer Functions
The token implements standard ERC20 transfer functions with additional features:

```solidity
function transfer(address to, uint256 amount) public virtual override returns (bool) {
    _updateDividendBalance(msg.sender);
    _updateDividendBalance(to);
    _updateVotingPower(msg.sender);
    _updateVotingPower(to);
    return super.transfer(to, amount);
}
```

Key Aspects:
- Automatic dividend balance updates
- Voting power adjustments
- Pausable functionality
- Reentrancy protection

### Permit Functionality
Implements EIP-2612 for gasless approvals:
```solidity
// Allows approval without gas costs
function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) public virtual override
```

## 4. Dividend System

### Overview
The dividend system enables automatic distribution of rewards to token holders.

### Key Components
1. Dividend Tracking:
```solidity
uint256 public totalDividendsDistributed;
uint256 public dividendPerTokenStored;
mapping(address => uint256) public lastDividendPerToken;
mapping(address => uint256) public unclaimedDividends;
```

2. Distribution Function:
```solidity
function distributeDividends() external payable nonReentrant onlyRole(DIVIDEND_MANAGER_ROLE) {
    require(msg.value > 0, "No dividends to distribute");
    require(totalSupply() > 0, "No tokens in circulation");
    
    uint256 dividendPerToken = msg.value.mul(DIVIDEND_PRECISION).div(totalSupply());
    dividendPerTokenStored = dividendPerTokenStored.add(dividendPerToken);
    totalDividendsDistributed = totalDividendsDistributed.add(msg.value);
}
```

### Claiming Process
1. Users can claim dividends at any time
2. Automatic balance updates during transfers
3. High precision calculations to prevent rounding errors

## 5. Governance System

### Proposal Creation
Requirements:
- Minimum token balance (100,000 VRX)
- Unique proposal hash
- Active token status

```solidity
function createProposal(bytes32 proposalHash) external returns (uint256)
```

### Voting Mechanism
Features:
- Weight-based voting (1 token = 1 vote)
- Time-locked voting period (3 days)
- Single vote per address per proposal

```solidity
function castVote(uint256 proposalId, bool support) external nonReentrant
```

### Proposal Execution
Conditions:
- Voting period ended
- More "for" votes than "against"
- Not already executed
- Called by governance manager

## 6. Vesting System

### Vesting Schedule Creation
```solidity
function createVestingSchedule(
    address beneficiary,
    uint256 totalAmount,
    uint256 startTime,
    uint256 cliffDuration,
    uint256 duration,
    bool revocable
)
```

Parameters:
- `beneficiary`: Recipient address
- `totalAmount`: Total tokens to be vested
- `startTime`: Vesting start timestamp
- `cliffDuration`: Initial lock period
- `duration`: Total vesting duration
- `revocable`: Whether schedule can be revoked

### Token Release
Features:
- Linear vesting after cliff period
- Automatic calculation of releasable amounts
- Safe release mechanism with reentrancy protection

### Revocation
Conditions:
- Only revocable schedules
- Only by vesting admin
- Releases vested amount to beneficiary
- Returns unvested tokens to admin

## 7. Security Features

### Access Control
- Role-based permissions
- Granular function access
- Multiple admin roles

### Reentrancy Protection
```solidity
modifier nonReentrant() {
    require(_notEntered, "ReentrancyGuard: reentrant call");
    _notEntered = false;
    _;
    _notEntered = true;
}
```

### Emergency Controls
```solidity
function pause() external onlyRole(ADMIN_ROLE)
function unpause() external onlyRole(ADMIN_ROLE)
```

## 8. Role Management

### Available Roles
1. DEFAULT_ADMIN_ROLE
   - Contract deployment
   - Role management
   - Emergency controls

2. DIVIDEND_MANAGER_ROLE
   - Dividend distribution
   - Distribution configuration

3. GOVERNANCE_MANAGER_ROLE
   - Proposal execution
   - Governance parameters

4. VESTING_ADMIN_ROLE
   - Vesting schedule creation
   - Schedule revocation

## 9. Integration Guide

### Contract Deployment
1. Deploy VerixToken
2. Deploy VerixTokenVesting with token address
3. Set up initial roles
4. Configure initial parameters

### Interface Integration
```typescript
interface IVerixToken {
    // ERC20 Interface
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    
    // Dividend Interface
    function claimDividends() external;
    function getDividendBalance(address account) external view returns (uint256);
    
    // Governance Interface
    function createProposal(bytes32 proposalHash) external returns (uint256);
    function castVote(uint256 proposalId, bool support) external;
}
```

## 10. Error Handling

### Common Error Messages
1. Token Operations:
   - "Transfer amount exceeds balance"
   - "Transfer to zero address"
   - "Insufficient allowance"

2. Dividend System:
   - "No dividends to distribute"
   - "No dividends to claim"
   - "Dividend transfer failed"

3. Governance:
   - "Insufficient tokens to propose"
   - "Voting period ended"
   - "Already voted"
   - "Proposal already executed"

4. Vesting:
   - "Invalid beneficiary"
   - "Schedule exists"
   - "Invalid durations"
   - "Schedule revoked"
   - "Not revocable"

### Error Prevention
1. Input Validation
2. Balance Checks
3. State Verification
4. Access Control
5. Arithmetic Overflow Protection

For additional support or technical queries, please contact the Verix development team or refer to our GitHub repository.
