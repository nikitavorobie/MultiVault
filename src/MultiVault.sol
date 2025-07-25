// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "./interfaces/IMultiVault.sol";

contract MultiVault is
    IMultiVault,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    mapping(address => Signer) private signers;
    mapping(uint256 => Proposal) private proposals;
    mapping(uint256 => mapping(address => bool)) private hasApproved;

    address[] private signerList;
    uint256 private proposalCount;
    uint256 private threshold;
    uint256 private totalWeight;

    error InvalidSigner();
    error SignerAlreadyExists();
    error SignerNotFound();
    error InvalidWeight();
    error InvalidThreshold();
    error ProposalNotFound();
    error ProposalAlreadyExecuted();
    error ProposalAlreadyCancelled();
    error InsufficientApprovals();
    error AlreadyApproved();
    error TransferFailed();

    function initialize(
        address[] memory _signers,
        uint256[] memory _weights,
        uint256 _threshold
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        if (_signers.length != _weights.length) revert InvalidSigner();
        if (_threshold == 0) revert InvalidThreshold();

        for (uint256 i = 0; i < _signers.length; i++) {
            _addSigner(_signers[i], _weights[i]);
        }

        if (_threshold > totalWeight) revert InvalidThreshold();
        threshold = _threshold;
    }

    function addSigner(address signer, uint256 weight) external override onlyOwner {
        _addSigner(signer, weight);
    }

    function removeSigner(address signer) external override onlyOwner {
        if (!signers[signer].active) revert SignerNotFound();

        totalWeight -= signers[signer].weight;
        signers[signer].active = false;

        for (uint256 i = 0; i < signerList.length; i++) {
            if (signerList[i] == signer) {
                signerList[i] = signerList[signerList.length - 1];
                signerList.pop();
                break;
            }
        }

        emit SignerRemoved(signer);
    }

    function updateSignerWeight(address signer, uint256 newWeight) external override onlyOwner {
        if (!signers[signer].active) revert SignerNotFound();
        if (newWeight == 0) revert InvalidWeight();

        totalWeight = totalWeight - signers[signer].weight + newWeight;
        signers[signer].weight = newWeight;

        emit SignerWeightUpdated(signer, newWeight);
    }

    function updateThreshold(uint256 newThreshold) external override onlyOwner {
        if (newThreshold == 0 || newThreshold > totalWeight) revert InvalidThreshold();
        threshold = newThreshold;
        emit ThresholdUpdated(newThreshold);
    }

    function createProposal(
        address recipient,
        uint256 amount,
        address token,
        bytes calldata data
    ) external override returns (uint256) {
        if (!signers[msg.sender].active) revert InvalidSigner();

        uint256 proposalId = proposalCount++;

        proposals[proposalId] = Proposal({
            id: proposalId,
            recipient: recipient,
            amount: amount,
            token: token,
            data: data,
            approvalWeight: 0,
            createdAt: block.timestamp,
            executed: false,
            cancelled: false
        });

        emit ProposalCreated(proposalId, recipient, amount);
        return proposalId;
    }

    function approveProposal(uint256 proposalId) external override {
        if (!signers[msg.sender].active) revert InvalidSigner();

        Proposal storage proposal = proposals[proposalId];
        if (proposal.createdAt == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalAlreadyCancelled();
        if (hasApproved[proposalId][msg.sender]) revert AlreadyApproved();

        hasApproved[proposalId][msg.sender] = true;
        proposal.approvalWeight += signers[msg.sender].weight;

        emit ProposalApproved(proposalId, msg.sender, signers[msg.sender].weight);
    }

    function executeProposal(uint256 proposalId) external override nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.createdAt == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalAlreadyCancelled();
        if (proposal.approvalWeight < threshold) revert InsufficientApprovals();

        proposal.executed = true;

        if (proposal.amount > 0) {
            if (proposal.token == address(0)) {
                (bool success, ) = proposal.recipient.call{value: proposal.amount}(proposal.data);
                if (!success) revert TransferFailed();
            } else {
                IERC20Upgradeable(proposal.token).safeTransfer(proposal.recipient, proposal.amount);
                if (proposal.data.length > 0) {
                    (bool success, ) = proposal.recipient.call(proposal.data);
                    if (!success) revert TransferFailed();
                }
            }
        } else if (proposal.data.length > 0) {
            (bool success, ) = proposal.recipient.call(proposal.data);
            if (!success) revert TransferFailed();
        }

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external override onlyOwner {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.createdAt == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalAlreadyCancelled();

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    function getProposal(uint256 proposalId) external view override returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getSigner(address signer) external view override returns (Signer memory) {
        return signers[signer];
    }

    function getTotalWeight() external view override returns (uint256) {
        return totalWeight;
    }

    function getThreshold() external view override returns (uint256) {
        return threshold;
    }

    function _addSigner(address signer, uint256 weight) private {
        if (signer == address(0)) revert InvalidSigner();
        if (signers[signer].active) revert SignerAlreadyExists();
        if (weight == 0) revert InvalidWeight();

        signers[signer] = Signer({
            addr: signer,
            weight: weight,
            active: true
        });

        signerList.push(signer);
        totalWeight += weight;

        emit SignerAdded(signer, weight);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}
}
