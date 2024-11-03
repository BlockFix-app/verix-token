// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IVerixRelayer.sol";
import "../interfaces/IVerixGasPool.sol";
import "../interfaces/IVerixGasOracle.sol";

/**
 * @title VerixRelayer
 * @notice Manages the relayer network for gas fee coverage
 * @dev Implements meta-transaction processing and gas fee management
 */
contract VerixRelayer is IVerixRelayer, ReentrancyGuard, AccessControl, Pausable {
    using ECDSA for bytes32;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    
    struct RelayerInfo {
        uint256 balance;
        uint256 nonce;
        bool isActive;
        uint256 totalTransactions;
        uint256 lastActivityTime;
        uint256 successfulRelays;
        uint256 failedRelays;
    }
    
    // State variables
    IVerixGasPool public immutable gasPool;
    IVerixGasOracle public immutable gasOracle;
    
    mapping(address => RelayerInfo) public relayers;
    mapping(bytes32 => bool) public processedRequests;
    mapping(address => uint256) public userNonces;
    
    uint256 public immutable minRelayerBalance;
    uint256 public immutable relayerTimeout;
    uint256 public constant MAX_GAS_LIMIT = 1000000;
    uint256 public constant REQUEST_TIMEOUT = 15 minutes;
    
    constructor(
        address _gasPool,
        address _gasOracle,
        uint256 _minRelayerBalance,
        uint256 _relayerTimeout
    ) {
        require(_gasPool != address(0), "Invalid gas pool");
        require(_gasOracle != address(0), "Invalid gas oracle");
        require(_minRelayerBalance > 0, "Invalid min balance");
        require(_relayerTimeout > 0, "Invalid timeout");
        
        gasPool = IVerixGasPool(_gasPool);
        gasOracle = IVerixGasOracle(_gasOracle);
        minRelayerBalance = _minRelayerBalance;
        relayerTimeout = _relayerTimeout;
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice Registers a new relayer
     */
    function registerRelayer() external payable override whenNotPaused {
        require(msg.value >= minRelayerBalance, "Insufficient initial balance");
        require(!relayers[msg.sender].isActive, "Already registered");
        
        relayers[msg.sender] = RelayerInfo({
            balance: msg.value,
            nonce: 0,
            isActive: true,
            totalTransactions: 0,
            lastActivityTime: block.timestamp,
            successfulRelays: 0,
            failedRelays: 0
        });
        
        _grantRole(RELAYER_ROLE, msg.sender);
        emit RelayerRegistered(msg.sender, msg.value);
    }
    
    /**
     * @notice Executes a relay request
     * @param request The relay request to execute
     */
    function executeRelay(RelayRequest calldata request) 
        external 
        override
        nonReentrant 
        onlyRole(RELAYER_ROLE) 
        whenNotPaused 
        returns (bool)
    {
        // Validate request
        require(block.timestamp < request.expiryTime, "Request expired");
        require(block.timestamp - request.expiryTime <= REQUEST_TIMEOUT, "Invalid expiry");
        require(relayers[msg.sender].isActive, "Relayer not active");
        require(request.gasAmount <= MAX_GAS_LIMIT, "Gas limit exceeded");
        
        // Validate signature
        bytes32 requestHash = keccak256(abi.encodePacked(
            request.user,
            request.gasAmount,
            request.nonce,
            request.expiryTime,
            request.data,
            address(this)
        ));
        
        require(!processedRequests[requestHash], "Already processed");
        require(request.nonce == userNonces[request.user], "Invalid nonce");
        
        address signer = requestHash.toEthSignedMessageHash().recover(request.signature);
        require(signer == request.user, "Invalid signature");
        
        // Calculate gas costs
        uint256 gasCost = gasOracle.calculateGasCost(request.gasAmount);
        require(relayers[msg.sender].balance >= gasCost, "Insufficient balance");
        
        // Process gas coverage
        uint256 coveredAmount = gasPool.coverGasFee(request.user, request.gasAmount);
        
        // Execute the transaction
        bool success = true;
        if (request.data.length > 0) {
            (success, ) = request.user.call{gas: request.gasAmount}(request.data);
        }
        
        // Update state
        processedRequests[requestHash] = true;
        userNonces[request.user]++;
        RelayerInfo storage relayer = relayers[msg.sender];
        relayer.balance -= gasCost;
        relayer.totalTransactions++;
        relayer.lastActivityTime = block.timestamp;
        
        if (success) {
            relayer.successfulRelays++;
        } else {
            relayer.failedRelays++;
        }
        
        emit RelayExecuted(
            request.user,
            msg.sender,
            request.gasAmount,
            requestHash
        );
        
        return success;
    }
    
    /**
     * @notice Tops up relayer balance
     */
    function topUpRelayer() external payable onlyRole(RELAYER_ROLE) {
        require(relayers[msg.sender].isActive, "Relayer not active");
        relayers[msg.sender].balance += msg.value;
        emit RelayerBalanceUpdated(msg.sender, relayers[msg.sender].balance);
    }
    
    /**
     * @notice Withdraws relayer balance
     * @param amount Amount to withdraw
     */
    function withdrawRelayerBalance(uint256 amount) 
        external 
        override
        nonReentrant 
        onlyRole(RELAYER_ROLE) 
    {
        RelayerInfo storage relayer = relayers[msg.sender];
        require(relayer.balance >= amount, "Insufficient balance");
        require(
            relayer.balance - amount >= minRelayerBalance,
            "Must maintain min balance"
        );
        
        relayer.balance -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        emit RelayerBalanceUpdated(msg.sender, relayer.balance);
    }
    
    /**
     * @notice Removes inactive relayer
     * @param relayerAddress Address of the relayer to remove
     */
    function removeInactiveRelayer(address relayerAddress) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        RelayerInfo storage relayer = relayers[relayerAddress];
        require(
            block.timestamp - relayer.lastActivityTime > relayerTimeout,
            "Relayer still active"
        );
        
        if (relayer.balance > 0) {
            (bool success, ) = relayerAddress.call{value: relayer.balance}("");
            require(success, "Transfer failed");
        }
        
        relayer.isActive = false;
        relayer.balance = 0;
        _revokeRole(RELAYER_ROLE, relayerAddress);
        
        emit RelayerRemoved(relayerAddress);
    }
    
    /**
     * @notice Gets relayer status
     * @param relayerAddress Address of the relayer
     */
    function getRelayerStatus(address relayerAddress) 
        external 
        view 
        override
        returns (
            bool isActive,
            uint256 balance,
            uint256 totalTransactions,
            uint256 lastActivityTime
        )
    {
        RelayerInfo storage relayer = relayers[relayerAddress];
        return (
            relayer.isActive,
            relayer.balance,
            relayer.totalTransactions,
            relayer.lastActivityTime
        );
    }
    
    /**
     * @notice Gets relayer performance metrics
     * @param relayerAddress Address of the relayer
     */
    function getRelayerMetrics(address relayerAddress)
        external
        view
        returns (
            uint256 successfulRelays,
            uint256 failedRelays,
            uint256 successRate
        )
    {
        RelayerInfo storage relayer = relayers[relayerAddress];
        uint256 totalRelays = relayer.successfulRelays + relayer.failedRelays;
        uint256 rate = totalRelays > 0 
            ? (relayer.successfulRelays * 100) / totalRelays 
            : 0;
            
        return (relayer.successfulRelays, relayer.failedRelays, rate);
    }
    
    /**
     * @notice Checks if a request has been processed
     * @param requestHash Hash of the request to check
     */
    function isRequestProcessed(bytes32 requestHash) external view returns (bool) {
        return processedRequests[requestHash];
    }
    
    /**
     * @notice Gets the next nonce for a user
     * @param user Address of the user
     */
    function getUserNonce(address user) external view returns (uint256) {
        return userNonces[user];
    }
    
    /**
     * @notice Emergency pause
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    /**
     * @notice Unpause
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    receive() external payable {
        emit RelayerBalanceUpdated(msg.sender, relayers[msg.sender].balance + msg.value);
    }
}

// Additional Events
event RelayerBalanceUpdated(address indexed relayer, uint256 newBalance);
