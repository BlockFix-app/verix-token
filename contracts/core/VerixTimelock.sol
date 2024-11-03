// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title VerixTimelock
 * @notice Implements timelock functionality for governance proposals with enhanced security features
 * @dev Extends OpenZeppelin's TimelockController with custom roles and execution rules
 */
contract VerixTimelock is TimelockController, AccessControl, Pausable {
    bytes32 public constant PROPOSAL_ROLE = keccak256("PROPOSAL_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    // Minimum delay that can be set for timelock
    uint256 public constant MIN_DELAY = 1 days;
    // Maximum delay that can be set for timelock
    uint256 public constant MAX_DELAY = 30 days;

    // Custom events
    event MinDelayChanged(uint256 oldDelay, uint256 newDelay);
    event OperationQueued(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 executionTime
    );
    event OperationExecuted(
        bytes32 indexed id,
        address indexed target,
        uint256 value,
        bytes data
    );
    event OperationCancelled(bytes32 indexed id);

    /**
     * @notice Contract constructor
     * @param minDelay Initial minimum timelock delay
     * @param proposers List of addresses that can propose
     * @param executors List of addresses that can execute
     * @param admin Address that will have admin role
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(
        minDelay,
        proposers,
        executors,
        admin
    ) {
        require(minDelay >= MIN_DELAY && minDelay <= MAX_DELAY, "Invalid delay");
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(PROPOSAL_ROLE, admin);
        _setupRole(EXECUTOR_ROLE, admin);
        _setupRole(CANCELLER_ROLE, admin);

        // Setup roles for proposers and executors
        for (uint256 i = 0; i < proposers.length; i++) {
            _setupRole(PROPOSAL_ROLE, proposers[i]);
        }
        for (uint256 i = 0; i < executors.length; i++) {
            _setupRole(EXECUTOR_ROLE, executors[i]);
        }
    }

    /**
     * @notice Schedule an operation with timelock
     * @param target Target address for the operation
     * @param value Value to be sent with the operation
     * @param data Function call data
     * @param predecessor Operation that must be executed before this one
     * @param salt Unique value for the operation
     */
    function schedule(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public virtual override onlyRole(PROPOSAL_ROLE) whenNotPaused {
        require(target != address(0), "Invalid target address");
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        uint256 executionTime = block.timestamp + getMinDelay();

        super.schedule(target, value, data, predecessor, salt);

        emit OperationQueued(id, target, value, data, executionTime);
    }

    /**
     * @notice Execute a scheduled operation
     * @param target Target address for the operation
     * @param value Value to be sent with the operation
     * @param data Function call data
     * @param predecessor Operation that must be executed before this one
     * @param salt Unique value for the operation
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public virtual override onlyRole(EXECUTOR_ROLE) whenNotPaused payable {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);

        super.execute(target, value, data, predecessor, salt);

        emit OperationExecuted(id, target, value, data);
    }

    /**
     * @notice Cancel a scheduled operation
     * @param target Target address for the operation
     * @param value Value to be sent with the operation
     * @param data Function call data
     * @param predecessor Operation that must be executed before this one
     * @param salt Unique value for the operation
     */
    function cancel(
        address target,
        uint256 value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) public virtual override onlyRole(CANCELLER_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);

        super.cancel(target, value, data, predecessor, salt);

        emit OperationCancelled(id);
    }

    /**
     * @notice Update the minimum delay for operations
     * @param newDelay New minimum delay in seconds
     */
    function updateDelay(uint256 newDelay) 
        public 
        virtual 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newDelay >= MIN_DELAY && newDelay <= MAX_DELAY, "Invalid delay");
        uint256 oldDelay = getMinDelay();
        super.updateDelay(newDelay);
        emit MinDelayChanged(oldDelay, newDelay);
    }

    /**
     * @notice Pause the timelock functionality
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the timelock functionality
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Check if an operation is pending
     * @param id Operation id
     * @return pending True if the operation is pending
     * @return executed True if the operation has been executed
     */
    function getOperationState(bytes32 id) 
        external 
        view 
        returns (bool pending, bool executed) 
    {
        pending = isOperationPending(id);
        executed = isOperationDone(id);
    }

    /**
     * @notice Get the timestamp at which an operation becomes executable
     * @param id Operation id
     * @return timestamp Timestamp when the operation can be executed
     */
    function getOperationTimestamp(bytes32 id) external view returns (uint256) {
        return getTimestamp(id);
    }
}
