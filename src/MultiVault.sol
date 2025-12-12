// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IMultiVault.sol";

contract MultiVault is
    IMultiVault,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    // ============================================
    // Roles
    // ============================================
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ============================================
    // Storage Layout (UUPS Upgradeability)
    // ============================================
    // Slots 0-99: OpenZeppelin Upgradeable (AccessControl, ReentrancyGuard, Pausable, UUPS)
    // Slots 100-149: Controller-level data
    // Slots 150-199: Reserved for future expansion (__gap)

    // Controller-level: Global proposal tracking across all vaults
    mapping(uint256 => Proposal) private proposals;              // slot 0
    mapping(uint256 => mapping(address => bool)) private hasApproved; // slot 1
    uint256 private proposalCount;                               // slot 2
    uint256 public proposalExpirationPeriod;                     // slot 3

    // Controller-level: Vault registry and factory
    mapping(uint256 => VaultInfo) private vaults;                // slot 4
    mapping(uint256 => mapping(address => Signer)) private vaultSigners; // slot 5
    mapping(uint256 => address[]) private vaultSignerList;       // slot 6
    uint256 private vaultCount;                                  // slot 7

    // Reserved for future controller-level features
    // Example: cross-vault policies, global limits, fee collection
    uint256[49] private __gap;

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
    error InvalidRecipient();
    error CannotRemoveLastSigner();
    error ProposalExpired();
    error VaultNotFound();
    error InvalidVaultName();
    error VaultAlreadyArchived();
    error CannotArchiveVaultWithActiveProposals();
    error Unauthorized();

    function initialize() public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        proposalExpirationPeriod = 30 days;
    }

    /// @notice Reinitializer for migrating from Ownable to AccessControl
    /// @dev Call this during upgrade from v1 to v2 to grant admin role to deployer
    function initializeV2() public reinitializer(2) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getVaultAdminRole(uint256 vaultId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("VAULT_ADMIN", vaultId));
    }

    function createVault(string calldata name, string calldata metadataRef) external override whenNotPaused returns (uint256) {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert Unauthorized();
        if (bytes(name).length == 0) revert InvalidVaultName();

        uint256 vaultId = vaultCount++;

        vaults[vaultId] = VaultInfo({
            id: vaultId,
            name: name,
            metadataRef: metadataRef,
            threshold: 0,
            totalWeight: 0,
            signerCount: 0,
            active: true
        });

        _grantRole(getVaultAdminRole(vaultId), msg.sender);

        emit VaultCreated(vaultId, name, metadataRef);
        return vaultId;
    }

    function addSigner(uint256 vaultId, address signer, uint256 weight) external override whenNotPaused {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(getVaultAdminRole(vaultId), msg.sender)) {
            revert Unauthorized();
        }
        if (!vaults[vaultId].active) revert VaultNotFound();
        if (signer == address(0)) revert InvalidSigner();
        if (vaultSigners[vaultId][signer].active) revert SignerAlreadyExists();
        if (weight == 0) revert InvalidWeight();

        vaultSigners[vaultId][signer] = Signer({
            addr: signer,
            weight: weight,
            active: true
        });

        vaultSignerList[vaultId].push(signer);
        vaults[vaultId].totalWeight += weight;
        vaults[vaultId].signerCount++;

        emit VaultSignerAdded(vaultId, signer, weight);
    }

    function removeSigner(uint256 vaultId, address signer) external override whenNotPaused {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(getVaultAdminRole(vaultId), msg.sender)) {
            revert Unauthorized();
        }
        if (!vaults[vaultId].active) revert VaultNotFound();
        if (!vaultSigners[vaultId][signer].active) revert SignerNotFound();

        uint256 listLength = vaultSignerList[vaultId].length;
        if (listLength <= 1) revert CannotRemoveLastSigner();

        vaults[vaultId].totalWeight -= vaultSigners[vaultId][signer].weight;
        vaults[vaultId].signerCount--;
        vaultSigners[vaultId][signer].active = false;

        for (uint256 i = 0; i < listLength; i++) {
            if (vaultSignerList[vaultId][i] == signer) {
                vaultSignerList[vaultId][i] = vaultSignerList[vaultId][listLength - 1];
                vaultSignerList[vaultId].pop();
                break;
            }
        }

        emit VaultSignerRemoved(vaultId, signer);
    }

    function setThreshold(uint256 vaultId, uint256 newThreshold) external override whenNotPaused {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(getVaultAdminRole(vaultId), msg.sender)) {
            revert Unauthorized();
        }
        if (!vaults[vaultId].active) revert VaultNotFound();
        if (newThreshold == 0 || newThreshold > vaults[vaultId].totalWeight) revert InvalidThreshold();

        uint256 oldThreshold = vaults[vaultId].threshold;
        vaults[vaultId].threshold = newThreshold;

        emit VaultThresholdUpdated(vaultId, oldThreshold, newThreshold);
    }

    function updateSignerWeight(uint256 vaultId, address signer, uint256 newWeight) external whenNotPaused {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(getVaultAdminRole(vaultId), msg.sender)) {
            revert Unauthorized();
        }
        if (!vaults[vaultId].active) revert VaultNotFound();
        if (!vaultSigners[vaultId][signer].active) revert SignerNotFound();
        if (newWeight == 0) revert InvalidWeight();

        uint256 oldWeight = vaultSigners[vaultId][signer].weight;
        vaults[vaultId].totalWeight = vaults[vaultId].totalWeight - oldWeight + newWeight;
        vaultSigners[vaultId][signer].weight = newWeight;

        emit VaultSignerWeightUpdated(vaultId, signer, oldWeight, newWeight);
    }

    function archiveVault(uint256 vaultId) external whenNotPaused {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert Unauthorized();
        if (!vaults[vaultId].active) revert VaultAlreadyArchived();

        vaults[vaultId].active = false;
        emit VaultArchived(vaultId);
    }

    function getVaultInfo(uint256 vaultId) external view override returns (VaultInfo memory) {
        return vaults[vaultId];
    }

    function getSignerInfo(uint256 vaultId, address signer) external view override returns (Signer memory) {
        return vaultSigners[vaultId][signer];
    }

    function createProposal(
        uint256 vaultId,
        address recipient,
        uint256 amount,
        address token,
        bytes calldata data
    ) external override whenNotPaused returns (uint256) {
        if (!vaults[vaultId].active) revert VaultNotFound();
        if (!vaultSigners[vaultId][msg.sender].active) revert InvalidSigner();
        if (recipient == address(0)) revert InvalidRecipient();

        uint256 proposalId = proposalCount++;

        proposals[proposalId] = Proposal({
            id: proposalId,
            vaultId: vaultId,
            recipient: recipient,
            amount: amount,
            token: token,
            data: data,
            approvalWeight: 0,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + proposalExpirationPeriod,
            executed: false,
            cancelled: false
        });

        emit ProposalCreated(proposalId, vaultId, recipient, amount);
        return proposalId;
    }

    function approveProposal(uint256 proposalId) external override whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.createdAt == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalAlreadyCancelled();
        if (block.timestamp > proposal.expiresAt) revert ProposalExpired();
        if (hasApproved[proposalId][msg.sender]) revert AlreadyApproved();

        uint256 vaultId = proposal.vaultId;
        if (!vaultSigners[vaultId][msg.sender].active) revert InvalidSigner();

        hasApproved[proposalId][msg.sender] = true;
        uint256 signerWeight = vaultSigners[vaultId][msg.sender].weight;
        proposal.approvalWeight += signerWeight;

        emit ProposalApproved(proposalId, msg.sender, signerWeight, proposal.approvalWeight);
    }

    function executeProposal(uint256 proposalId) external override nonReentrant whenNotPaused {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.createdAt == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalAlreadyCancelled();
        if (block.timestamp > proposal.expiresAt) revert ProposalExpired();

        uint256 vaultId = proposal.vaultId;
        if (proposal.approvalWeight < vaults[vaultId].threshold) revert InsufficientApprovals();

        proposal.executed = true;

        if (proposal.amount > 0) {
            if (proposal.token == address(0)) {
                (bool success, ) = proposal.recipient.call{value: proposal.amount}(proposal.data);
                if (!success) revert TransferFailed();
            } else {
                IERC20(proposal.token).safeTransfer(proposal.recipient, proposal.amount);
                if (proposal.data.length > 0) {
                    (bool success, ) = proposal.recipient.call(proposal.data);
                    if (!success) revert TransferFailed();
                }
            }
        } else if (proposal.data.length > 0) {
            (bool success, ) = proposal.recipient.call(proposal.data);
            if (!success) revert TransferFailed();
        }

        emit ProposalExecuted(proposalId, proposal.recipient, proposal.amount);
    }

    function cancelProposal(uint256 proposalId) external override whenNotPaused {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert Unauthorized();
        Proposal storage proposal = proposals[proposalId];
        if (proposal.createdAt == 0) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalAlreadyCancelled();

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId, msg.sender);
    }

    function getProposal(uint256 proposalId) external view override returns (Proposal memory) {
        return proposals[proposalId];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }

    function getVaultCount() external view returns (uint256) {
        return vaultCount;
    }

    function hasApprovedProposal(uint256 proposalId, address signer) external view returns (bool) {
        return hasApproved[proposalId][signer];
    }

    function pause() external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(PAUSER_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _pause();
    }

    function unpause() external {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && !hasRole(PAUSER_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert Unauthorized();
    }

    receive() external payable {}
}
