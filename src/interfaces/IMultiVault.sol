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

    event SignerAdded(address indexed signer, uint256 weight);
    event SignerRemoved(address indexed signer);
    event SignerWeightUpdated(address indexed signer, uint256 oldWeight, uint256 newWeight);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event ProposalCreated(uint256 indexed proposalId, address indexed recipient, uint256 amount, address token);
    event ProposalApproved(uint256 indexed proposalId, address indexed approver, uint256 weight, uint256 totalWeight);
    event ProposalExecuted(uint256 indexed proposalId, address indexed recipient, uint256 amount);
    event ProposalCancelled(uint256 indexed proposalId, address indexed cancelledBy);

    function addSigner(address signer, uint256 weight) external;
    function removeSigner(address signer) external;
    function updateSignerWeight(address signer, uint256 newWeight) external;
    function updateThreshold(uint256 newThreshold) external;

    function createProposal(address recipient, uint256 amount, address token, bytes calldata data) external returns (uint256);
    function approveProposal(uint256 proposalId) external;
    function executeProposal(uint256 proposalId) external;
    function cancelProposal(uint256 proposalId) external;

    function getProposal(uint256 proposalId) external view returns (Proposal memory);
    function getSigner(address signer) external view returns (Signer memory);
    function getTotalWeight() external view returns (uint256);
    function getThreshold() external view returns (uint256);
}
