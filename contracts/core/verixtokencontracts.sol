// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title VerixToken
 * @notice Main token contract implementing ERC20 with permit, dividends, and governance
 */
contract VerixToken is ERC20Permit, Pausable, AccessControl, ReentrancyGuard {
    using SafeMath for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DIVIDEND_MANAGER_ROLE = keccak256("DIVIDEND_MANAGER_ROLE");
    bytes32 public constant GOVERNANCE_MANAGER_ROLE = keccak256("GOVERNANCE_MANAGER_ROLE");

    uint256 private constant INITIAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 private constant DIVIDEND_PRECISION = 1e12;
    uint256 private constant GOVERNANCE_VOTING_PERIOD = 3 days;

    // Dividend tracking
    uint256 public totalDividendsDistributed;
    uint256 public dividendPerTokenStored;
    mapping(address => uint256) public lastDividendPerToken;
    mapping(address => uint256) public unclaimedDividends;

    // Governance
    struct Proposal {
        address proposer;
        bytes32 proposalHash;
        uint256 startTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public votingPower;

    // Events
    event DividendDistributed(uint256 amount, uint256 timestamp);
    event DividendClaimed(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address proposer, bytes32 proposalHash);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    constructor() 
        ERC20("Verix Token", "VRX") 
        ERC20Permit("Verix Token") 
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(DIVIDEND_MANAGER_ROLE, msg.sender);
        _setupRole(GOVERNANCE_MANAGER_ROLE, msg.sender);
        
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // Core token functionality with dividend and governance integration
    function transfer(address to, uint256 amount) 
        public 
        virtual 
        override 
        whenNotPaused 
        returns (bool) 
    {
        _updateDividendBalance(msg.sender);
        _updateDividendBalance(to);
        _updateVotingPower(msg.sender);
        _updateVotingPower(to);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        _updateDividendBalance(from);
        _updateDividendBalance(to);
        _updateVotingPower(from);
        _updateVotingPower(to);
        return super.transferFrom(from, to, amount);
    }

    // Dividend functionality
    function distributeDividends() 
        external 
        payable 
        nonReentrant 
        onlyRole(DIVIDEND_MANAGER_ROLE) 
    {
        require(msg.value > 0, "No dividends to distribute");
        require(totalSupply() > 0, "No tokens in circulation");

        uint256 dividendPerToken = msg.value.mul(DIVIDEND_PRECISION).div(totalSupply());
        dividendPerTokenStored = dividendPerTokenStored.add(dividendPerToken);
        totalDividendsDistributed = totalDividendsDistributed.add(msg.value);

        emit DividendDistributed(msg.value, block.timestamp);
    }

    function claimDividends() external nonReentrant {
        _updateDividendBalance(msg.sender);
        uint256 dividends = unclaimedDividends[msg.sender];
        require(dividends > 0, "No dividends to claim");

        unclaimedDividends[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: dividends}("");
        require(success, "Dividend transfer failed");

        emit DividendClaimed(msg.sender, dividends);
    }

    function _updateDividendBalance(address account) internal {
        uint256 newDividends = balanceOf(account)
            .mul(dividendPerTokenStored.sub(lastDividendPerToken[account]))
            .div(DIVIDEND_PRECISION);

        if (newDividends > 0) {
            unclaimedDividends[account] = unclaimedDividends[account].add(newDividends);
            lastDividendPerToken[account] = dividendPerTokenStored;
        }
    }

    // Governance functionality
    function createProposal(bytes32 proposalHash) 
        external 
        returns (uint256) 
    {
        require(balanceOf(msg.sender) >= 100000 * 10**18, "Insufficient tokens to propose");
        
        proposalCount++;
        Proposal storage proposal = proposals[proposalCount];
        proposal.proposer = msg.sender;
        proposal.proposalHash = proposalHash;
        proposal.startTime = block.timestamp;

        emit ProposalCreated(proposalCount, msg.sender, proposalHash);
        return proposalCount;
    }

    function castVote(uint256 proposalId, bool support) 
        external 
        nonReentrant 
    {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp <= proposal.startTime + GOVERNANCE_VOTING_PERIOD, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed, "Proposal already executed");

        uint256 weight = balanceOf(msg.sender);
        require(weight > 0, "No voting power");

        proposal.hasVoted[msg.sender] = true;
        if (support) {
            proposal.forVotes = proposal.forVotes.add(weight);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(weight);
        }

        emit VoteCast(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) 
        external 
        onlyRole(GOVERNANCE_MANAGER_ROLE) 
    {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Already executed");
        require(
            block.timestamp > proposal.startTime + GOVERNANCE_VOTING_PERIOD,
            "Voting period not ended"
        );
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function _updateVotingPower(address account) internal {
        votingPower[account] = balanceOf(account);
    }

    // Admin functions
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // Required overrides
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    receive() external payable {
        // Accept ETH for dividends
    }
}

/**
 * @title VerixTokenVesting
 * @notice Handles token vesting for team, advisors, and partners
 */
contract VerixTokenVesting is AccessControl, ReentrancyGuard {
    using SafeMath for uint256;

    bytes32 public constant VESTING_ADMIN_ROLE = keccak256("VESTING_ADMIN_ROLE");
    
    VerixToken public verixToken;
    
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 duration;
        uint256 releasedAmount;
        bool revocable;
        bool revoked;
    }
    
    mapping(address => VestingSchedule) public vestingSchedules;
    
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 duration
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);
    
    constructor(address _verixToken) {
        verixToken = VerixToken(_verixToken);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(VESTING_ADMIN_ROLE, msg.sender);
    }
    
    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 duration,
        bool revocable
    ) external onlyRole(VESTING_ADMIN_ROLE) {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Schedule exists");
        require(duration > cliffDuration, "Invalid durations");
        
        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            startTime: startTime,
            cliffDuration: cliffDuration,
            duration: duration,
            releasedAmount: 0,
            revocable: revocable,
            revoked: false
        });
        
        emit VestingScheduleCreated(
            beneficiary,
            totalAmount,
            startTime,
            cliffDuration,
            duration
        );
    }
    
    function release() external nonReentrant {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Schedule revoked");
        
        uint256 releasableAmount = _getReleasableAmount(schedule);
        require(releasableAmount > 0, "No tokens to release");
        
        schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
        require(
            verixToken.transfer(msg.sender, releasableAmount),
            "Transfer failed"
        );
        
        emit TokensReleased(msg.sender, releasableAmount);
    }
    
    function revoke(address beneficiary) 
        external 
        onlyRole(VESTING_ADMIN_ROLE) 
    {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        require(schedule.revocable, "Not revocable");
        require(!schedule.revoked, "Already revoked");
        
        uint256 releasableAmount = _getReleasableAmount(schedule);
        if (releasableAmount > 0) {
            schedule.releasedAmount = schedule.releasedAmount.add(releasableAmount);
            require(
                verixToken.transfer(beneficiary, releasableAmount),
                "Transfer failed"
            );
            emit TokensReleased(beneficiary, releasableAmount);
        }
        
        uint256 remainingAmount = schedule.totalAmount.sub(schedule.releasedAmount);
        if (remainingAmount > 0) {
            require(
                verixToken.transfer(msg.sender, remainingAmount),
                "Transfer failed"
            );
        }
        
        schedule.revoked = true;
        emit VestingRevoked(beneficiary);
    }
    
    function _getReleasableAmount(VestingSchedule storage schedule) 
        internal 
        view 
        returns (uint256) 
    {
        if (block.timestamp < schedule.startTime.add(schedule.cliffDuration)) {
            return 0;
        }
        
        if (block.timestamp >= schedule.startTime.add(schedule.duration)) {
            return schedule.totalAmount.sub(schedule.releasedAmount);
        }
        
        uint256 timeFromStart = block.timestamp.sub(schedule.startTime);
        uint256 vestedAmount = schedule.totalAmount
            .mul(timeFromStart)
            .div(schedule.duration);
            
        return vestedAmount.sub(schedule.releasedAmount);
    }
    
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
            bool revoked
        )
    {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        return (
            schedule.totalAmount,
            schedule.startTime,
            schedule.cliffDuration,
            schedule.duration,
            schedule.releasedAmount,
            schedule.revocable,
            schedule.revoked
        );
    }
}
