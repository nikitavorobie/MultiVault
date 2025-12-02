// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMultiVault {
    struct Signer {
        address addr;
        uint256 weight;
        bool active;
    }

    struct Proposal {
        uint256 id;
        uint256 vaultId;
        address recipient;
        uint256 amount;
        address token;
        bytes data;
        uint256 approvalWeight;
        uint256 createdAt;
        uint256 expiresAt;
        bool executed;
        bool cancelled;
    }

    struct VaultInfo {
        uint256 id;
        string name;
        string metadataRef;
        uint256 threshold;
        uint256 totalWeight;
        uint256 signerCount;
        bool active;
    }

    event VaultCreated(uint256 indexed vaultId, string name, string metadataRef);
    event VaultSignerAdded(uint256 indexed vaultId, address indexed signer, uint256 weight);
    event VaultSignerRemoved(uint256 indexed vaultId, address indexed signer);
    event VaultThresholdUpdated(uint256 indexed vaultId, uint256 oldThreshold, uint256 newThreshold);
    event ProposalCreated(uint256 indexed proposalId, uint256 indexed vaultId, address indexed recipient, uint256 amount);
    event ProposalApproved(uint256 indexed proposalId, address indexed approver, uint256 weight, uint256 totalWeight);
    event ProposalExecuted(uint256 indexed proposalId, address indexed recipient, uint256 amount);
    event ProposalCancelled(uint256 indexed proposalId, address indexed cancelledBy);

    function createVault(string calldata name, string calldata metadataRef) external returns (uint256);
    function addSigner(uint256 vaultId, address signer, uint256 weight) external;
    function removeSigner(uint256 vaultId, address signer) external;
    function setThreshold(uint256 vaultId, uint256 threshold) external;
    function getVaultInfo(uint256 vaultId) external view returns (VaultInfo memory);
    function getSignerInfo(uint256 vaultId, address signer) external view returns (Signer memory);

    function createProposal(uint256 vaultId, address recipient, uint256 amount, address token, bytes calldata data) external returns (uint256);
    function approveProposal(uint256 proposalId) external;
    function executeProposal(uint256 proposalId) external;
    function cancelProposal(uint256 proposalId) external;

    function getProposal(uint256 proposalId) external view returns (Proposal memory);
}
