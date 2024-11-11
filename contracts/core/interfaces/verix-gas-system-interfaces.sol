// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IVerixGasOracle
 * @notice Interface for the gas price oracle contract
 */
interface IVerixGasOracle {
    event GasPriceUpdated(uint256 newPrice, uint256 timestamp);
    event MaticPriceUpdated(uint256 newPrice, uint256 timestamp);

    function updatePrices() external;
    function calculateGasCost(uint256 gasAmount) external view returns (uint256);
    function maticToUsd(uint256 maticAmount) external view returns (uint256);
}

/**
 * @title IVerixGasPool
 * @notice Interface for the gas pool contract
 */
interface IVerixGasPool {
    struct Tier {
        uint256 minTokens;
        uint256 coveragePercent;
        uint256 maxDailyGas;
    }
    
    event GasCovered(address indexed user, uint256 amount, uint256 tierLevel);
    event TierUpdated(address indexed user, uint256 newTier);
    event PoolReplenished(uint256 amount);
    
    function updateUserTier(address user) external;
    function coverGasFee(address user, uint256 gasAmount) external returns (uint256);
    function replenishPool() external payable;
    function updateTier(
        uint256 tierId,
        uint256 minTokens,
        uint256 coveragePercent,
        uint256 maxDailyGas
    ) external;
}

/**
 * @title IVerixRelayer
 * @notice Interface for the transaction relayer contract
 */
interface IVerixRelayer {
    struct RelayRequest {
        address user;
        uint256 gasAmount;
        uint256 nonce;
        uint256 expiryTime;
        bytes signature;
        bytes data;
    }
    
    event RelayerRegistered(address indexed relayer, uint256 deposit);
    event RelayerRemoved(address indexed relayer);
    event RelayExecuted(
        address indexed user,
        address indexed relayer,
        uint256 gasAmount,
        bytes32 indexed transactionHash
    );
    
    function registerRelayer() external payable;
    function executeRelay(RelayRequest calldata request) external returns (bool);
    function withdrawRelayerBalance(uint256 amount) external;
    function getRelayerStatus(address relayer) external view returns (
        bool isActive,
        uint256 balance,
        uint256 totalTransactions,
        uint256 lastActivityTime
    );
}

/**
 * @title IVerixToken
 * @notice Interface for the main Verix token contract
 */
interface IVerixToken {
    // Events
    event DividendDistributed(uint256 amount, uint256 timestamp);
    event DividendClaimed(address indexed user, uint256 amount);
    event ProposalCreated(uint256 indexed proposalId, address proposer, bytes32 proposalHash);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed proposalId);

    // ERC20 functions
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    // Dividend functions
    function distributeDividends() external payable;
    function claimDividends() external;
    function unclaimedDividends(address account) external view returns (uint256);

    // Governance functions
    function createProposal(bytes32 proposalHash) external returns (uint256);
    function castVote(uint256 proposalId, bool support) external;
    function executeProposal(uint256 proposalId) external;
    function getProposalState(uint256 proposalId) external view returns (
        address proposer,
        bytes32 proposalHash,
        uint256 startTime,
        uint256 forVotes,
        uint256 againstVotes,
        bool executed
    );
}

/**
 * @title IVerixGovernor
 * @notice Interface for the governance contract
 */
interface IVerixGovernor {
    struct ProposalCore {
        uint256 startBlock;
        uint256 endBlock;
        bool executed;
        bool canceled;
    }

    event ProposalCreated(
        uint256 proposalId,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event ProposalExecuted(uint256 proposalId);
    event ProposalCanceled(uint256 proposalId);
    event VoteCast(address indexed voter, uint256 proposalId, bool support, uint256 weight);

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    function execute(uint256 proposalId) external payable;
    function cancel(uint256 proposalId) external;
    function castVote(uint256 proposalId, bool support) external;
    function state(uint256 proposalId) external view returns (uint8);
}
