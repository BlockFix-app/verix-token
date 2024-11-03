// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title VerixGasOracle
 * @notice Manages gas price data and calculations for the Verix ecosystem
 */
contract VerixGasOracle {
    using ECDSA for bytes32;

    AggregatorV3Interface public maticUsdPriceFeed;
    AggregatorV3Interface public gasWeiPriceFeed;
    
    uint256 public constant PRICE_PRECISION = 1e8;
    uint256 public lastUpdateTimestamp;
    uint256 public gasPrice;
    uint256 public maticUsdPrice;
    
    event GasPriceUpdated(uint256 newPrice);
    event MaticPriceUpdated(uint256 newPrice);
    
    constructor(address _maticUsdPriceFeed, address _gasWeiPriceFeed) {
        maticUsdPriceFeed = AggregatorV3Interface(_maticUsdPriceFeed);
        gasWeiPriceFeed = AggregatorV3Interface(_gasWeiPriceFeed);
        updatePrices();
    }
    
    /**
     * @notice Updates both MATIC/USD and gas prices
     */
    function updatePrices() public {
        // Update MATIC/USD price
        (
            ,
            int256 maticPrice,
            ,
            uint256 maticUpdateTime,
        ) = maticUsdPriceFeed.latestRoundData();
        require(maticPrice > 0, "Invalid MATIC price");
        maticUsdPrice = uint256(maticPrice);
        
        // Update gas price in Wei
        (
            ,
            int256 gasWeiPrice,
            ,
            uint256 gasUpdateTime,
        ) = gasWeiPriceFeed.latestRoundData();
        require(gasWeiPrice > 0, "Invalid gas price");
        gasPrice = uint256(gasWeiPrice);
        
        lastUpdateTimestamp = block.timestamp;
        
        emit MaticPriceUpdated(maticUsdPrice);
        emit GasPriceUpdated(gasPrice);
    }
    
    /**
     * @notice Calculates gas cost in MATIC for a given gas amount
     */
    function calculateGasCost(uint256 gasAmount) public view returns (uint256) {
        return (gasAmount * gasPrice) / PRICE_PRECISION;
    }
    
    /**
     * @notice Converts MATIC amount to USD value
     */
    function maticToUsd(uint256 maticAmount) public view returns (uint256) {
        return (maticAmount * maticUsdPrice) / PRICE_PRECISION;
    }
}

/**
 * @title VerixRelayer
 * @notice Manages the relayer network for gas fee coverage
 */
contract VerixRelayer is ReentrancyGuard, AccessControl, Pausable {
    using ECDSA for bytes32;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    
    struct RelayerInfo {
        uint256 balance;
        uint256 nonce;
        bool isActive;
        uint256 totalTransactions;
        uint256 lastActivityTime;
    }
    
    struct RelayRequest {
        address user;
        uint256 gasAmount;
        uint256 nonce;
        uint256 expiryTime;
        bytes signature;
    }
    
    mapping(address => RelayerInfo) public relayers;
    mapping(bytes32 => bool) public processedRequests;
    mapping(address => uint256) public userNonces;
    
    VerixGasPool public gasPool;
    VerixGasOracle public gasOracle;
    
    uint256 public minRelayerBalance;
    uint256 public relayerTimeout;
    
    event RelayerRegistered(address indexed relayer);
    event RelayerRemoved(address indexed relayer);
    event RelayExecuted(
        address indexed user,
        address indexed relayer,
        uint256 gasAmount,
        uint256 actualCost
    );
    event RelayerBalanceUpdated(address indexed relayer, uint256 newBalance);
    
    constructor(
        address _gasPool,
        address _gasOracle,
        uint256 _minRelayerBalance,
        uint256 _relayerTimeout
    ) {
        gasPool = VerixGasPool(_gasPool);
        gasOracle = VerixGasOracle(_gasOracle);
        minRelayerBalance = _minRelayerBalance;
        relayerTimeout = _relayerTimeout;
        
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice Registers a new relayer
     */
    function registerRelayer() external payable {
        require(msg.value >= minRelayerBalance, "Insufficient initial balance");
        require(!relayers[msg.sender].isActive, "Relayer already registered");
        
        relayers[msg.sender] = RelayerInfo({
            balance: msg.value,
            nonce: 0,
            isActive: true,
            totalTransactions: 0,
            lastActivityTime: block.timestamp
        });
        
        _grantRole(RELAYER_ROLE, msg.sender);
        emit RelayerRegistered(msg.sender);
    }
    
    /**
     * @notice Executes a relay request
     */
    function executeRelay(RelayRequest calldata request) 
        external 
        nonReentrant 
        onlyRole(RELAYER_ROLE) 
        whenNotPaused 
        returns (bool)
    {
        require(block.timestamp < request.expiryTime, "Request expired");
        require(relayers[msg.sender].isActive, "Relayer not active");
        
        bytes32 requestHash = keccak256(abi.encodePacked(
            request.user,
            request.gasAmount,
            request.nonce,
            request.expiryTime,
            address(this)
        ));
        
        require(!processedRequests[requestHash], "Request already processed");
        require(request.nonce == userNonces[request.user], "Invalid nonce");
        
        address signer = requestHash.toEthSignedMessageHash().recover(request.signature);
        require(signer == request.user, "Invalid signature");
        
        // Calculate actual gas cost
        uint256 gasCost = gasOracle.calculateGasCost(request.gasAmount);
        require(relayers[msg.sender].balance >= gasCost, "Insufficient relayer balance");
        
        // Process gas coverage through gas pool
        uint256 coveredAmount = gasPool.coverGasFee(request.user, request.gasAmount);
        
        // Update state
        processedRequests[requestHash] = true;
        userNonces[request.user]++;
        relayers[msg.sender].balance -= gasCost;
        relayers[msg.sender].totalTransactions++;
        relayers[msg.sender].lastActivityTime = block.timestamp;
        
        emit RelayExecuted(request.user, msg.sender, request.gasAmount, coveredAmount);
        return true;
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
     */
    function withdrawRelayerBalance(uint256 amount) 
        external 
        nonReentrant 
        onlyRole(RELAYER_ROLE) 
    {
        require(relayers[msg.sender].balance >= amount, "Insufficient balance");
        require(
            relayers[msg.sender].balance - amount >= minRelayerBalance,
            "Must maintain minimum balance"
        );
        
        relayers[msg.sender].balance -= amount;
        payable(msg.sender).transfer(amount);
        emit RelayerBalanceUpdated(msg.sender, relayers[msg.sender].balance);
    }
    
    /**
     * @notice Removes inactive relayers
     */
    function removeInactiveRelayer(address relayer) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            block.timestamp - relayers[relayer].lastActivityTime > relayerTimeout,
            "Relayer still active"
        );
        
        relayers[relayer].isActive = false;
        _revokeRole(RELAYER_ROLE, relayer);
        emit RelayerRemoved(relayer);
    }
    
    /**
     * @notice Gets relayer status
     */
    function getRelayerStatus(address relayer) 
        external 
        view 
        returns (
            bool isActive,
            uint256 balance,
            uint256 totalTransactions,
            uint256 lastActivityTime
        )
    {
        RelayerInfo memory info = relayers[relayer];
        return (
            info.isActive,
            info.balance,
            info.totalTransactions,
            info.lastActivityTime
        );
    }
}

/**
 * @title VerixMetaTransaction
 * @notice Handles meta-transactions for gas-less operations
 */
contract VerixMetaTransaction {
    using ECDSA for bytes32;

    struct MetaTransaction {
        uint256 nonce;
        address from;
        bytes functionSignature;
    }
    
    mapping(address => uint256) private nonces;
    
    event MetaTransactionExecuted(
        address indexed from,
        address indexed relayer,
        bytes functionSignature
    );
    
    /**
     * @notice Executes a meta-transaction
     */
    function executeMetaTransaction(
        address from,
        bytes memory functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) external payable returns (bytes memory) {
        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[from],
            from: from,
            functionSignature: functionSignature
        });
        
        require(verify(from, metaTx, sigR, sigS, sigV), "Invalid signature");
        nonces[from]++;
        
        emit MetaTransactionExecuted(from, msg.sender, functionSignature);
        
        // Execute the actual function
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(functionSignature, from)
        );
        require(success, "Function call failed");
        
        return returnData;
    }
    
    /**
     * @notice Verifies meta-transaction signature
     */
    function verify(
        address from,
        MetaTransaction memory metaTx,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            getDomainSeparator(),
            keccak256(abi.encode(
                keccak256("MetaTransaction(uint256 nonce,address from,bytes functionSignature)"),
                metaTx.nonce,
                metaTx.from,
                keccak256(metaTx.functionSignature)
            ))
        ));
        
        return ecrecover(digest, sigV, sigR, sigS) == from;
    }
    
    function getDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes("Verix Protocol")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        ));
    }
    
    /**
     * @notice Gets the next nonce for an address
     */
    function getNonce(address user) external view returns (uint256) {
        return nonces[user];
    }
}
