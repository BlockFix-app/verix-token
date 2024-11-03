// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title VerixAccessControl
 * @notice Centralizes role management for the Verix ecosystem
 * @dev Implements a hierarchical role system with time-locked role transfers
 */
contract VerixAccessControl is AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant SYSTEM_ADMIN_ROLE = keccak256("SYSTEM_ADMIN_ROLE");
    bytes32 public constant GAS_MANAGER_ROLE = keccak256("GAS_MANAGER_ROLE");
    bytes32 public constant DIVIDEND_MANAGER_ROLE = keccak256("DIVIDEND_MANAGER_ROLE");
    bytes32 public constant GOVERNANCE_MANAGER_ROLE = keccak256("GOVERNANCE_MANAGER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Role transfer requests
    struct RoleTransfer {
        address newAdmin;
        uint256 effectiveTime;
        bool pending;
    }

    // Mapping from role to transfer request
    mapping(bytes32 => RoleTransfer) public roleTransfers;

    // Time delay for role transfers
    uint256 public constant ROLE_TRANSFER_DELAY = 2 days;

    // Events
    event RoleTransferRequested(
        bytes32 indexed role,
        address indexed currentAdmin,
        address indexed newAdmin,
        uint256 effectiveTime
    );
    event RoleTransferCompleted(
        bytes32 indexed role,
        address indexed oldAdmin,
        address indexed newAdmin
    );
    event RoleTransferCancelled(bytes32 indexed role);
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @notice Contract constructor
     * @param admin Address that will have the default admin role
     */
    constructor(address admin) {
        require(admin != address(0), "Invalid admin address");

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(SYSTEM_ADMIN_ROLE, admin);

        // Set role hierarchy
        _setRoleAdmin(GAS_MANAGER_ROLE, SYSTEM_ADMIN_ROLE);
        _setRoleAdmin(DIVIDEND_MANAGER_ROLE, SYSTEM_ADMIN_ROLE);
        _setRoleAdmin(GOVERNANCE_MANAGER_ROLE, SYSTEM_ADMIN_ROLE);
        _setRoleAdmin(OPERATOR_ROLE, SYSTEM_ADMIN_ROLE);
    }

    /**
     * @notice Initiates a role transfer request
     * @param role Role to transfer
     * @param newAdmin Address of the new admin
     */
    function initiateRoleTransfer(bytes32 role, address newAdmin) 
        external 
        onlyRole(getRoleAdmin(role)) 
    {
        require(newAdmin != address(0), "Invalid new admin address");
        require(!roleTransfers[role].pending, "Transfer already pending");

        uint256 effectiveTime = block.timestamp + ROLE_TRANSFER_DELAY;
        roleTransfers[role] = RoleTransfer({
            newAdmin: newAdmin,
            effectiveTime: effectiveTime,
            pending: true
        });

        emit RoleTransferRequested(role, msg.sender, newAdmin, effectiveTime);
    }

    /**
     * @notice Completes a pending role transfer
     * @param role Role being transferred
     */
    function completeRoleTransfer(bytes32 role) 
        external 
        nonReentrant 
    {
        RoleTransfer memory transfer = roleTransfers[role];
        require(transfer.pending, "No pending transfer");
        require(block.timestamp >= transfer.effectiveTime, "Transfer not yet effective");
        require(msg.sender == transfer.newAdmin, "Only new admin can complete");

        address oldAdmin = getRoleMember(getRoleAdmin(role), 0);
        _revokeRole(getRoleAdmin(role), oldAdmin);
        _grantRole(getRoleAdmin(role), transfer.newAdmin);

        delete roleTransfers[role];

        emit RoleTransferCompleted(role, oldAdmin, transfer.newAdmin);
    }

    /**
     * @notice Cancels a pending role transfer
     * @param role Role whose transfer is being cancelled
     */
    function cancelRoleTransfer(bytes32 role) 
        external 
        onlyRole(getRoleAdmin(role)) 
    {
        require(roleTransfers[role].pending, "No pending transfer");
        delete roleTransfers[role];
        emit RoleTransferCancelled(role);
    }

    /**
     * @notice Grants a role to an account
     * @param role Role to grant
     * @param account Account to receive the role
     */
    function grantRole(bytes32 role, address account)
        public
        virtual
        override
        onlyRole(getRoleAdmin(role))
    {
        super.grantRole(role, account);
    }

    /**
     * @notice Revokes a role from an account
     * @param role Role to revoke
     * @param account Account to revoke the role from
     */
    function revokeRole(bytes32 role, address account)
        public
        virtual
        override
        onlyRole(getRoleAdmin(role))
    {
        require(
            role != DEFAULT_ADMIN_ROLE || 
            getRoleMemberCount(role) > 1,
            "Cannot revoke last admin"
        );
        super.revokeRole(role, account);
    }

    /**
     * @notice Checks if a role transfer is pending
     * @param role Role to check
     * @return pending Whether a transfer is pending
     * @return newAdmin Address of the pending new admin
     * @return effectiveTime Time when the transfer becomes effective
     */
    function getRoleTransferStatus(bytes32 role)
        external
        view
        returns (
            bool pending,
            address newAdmin,
            uint256 effectiveTime
        )
    {
        RoleTransfer memory transfer = roleTransfers[role];
        return (transfer.pending, transfer.newAdmin, transfer.effectiveTime);
    }

    /**
     * @notice Pauses all role management operations
     */
    function pause() external onlyRole(SYSTEM_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses role management operations
     */
    function unpause() external onlyRole(SYSTEM_ADMIN_ROLE) {
        _unpause();
    }
}
