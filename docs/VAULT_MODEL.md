# Vault Model Specification

## Overview

MultiVault implements a multi-tenant vault architecture where each vault operates as an independent multi-signature treasury with its own governance rules, signers, and approval thresholds.

## Vault Lifecycle

### States

**Active** → **Archived**

- **Active**: Vault accepts new signers, proposals, and configuration changes
- **Archived**: Vault is permanently disabled; no operations allowed

### Lifecycle Operations

```solidity
// Creation
uint256 vaultId = multiVault.createVault("DAO Treasury", "ipfs://QmMetadata...");

// Operation (active state)
multiVault.addSigner(vaultId, signer, weight);
multiVault.createProposal(vaultId, recipient, amount, token, data);

// Archival (terminal state)
multiVault.archiveVault(vaultId);
// After archival: all vault operations revert with VaultNotFound
```

### Archival Rules

- Only owner can archive vaults
- Archival is irreversible
- Archived vaults cannot:
  - Add/remove signers
  - Update thresholds or weights
  - Create new proposals
  - Approve or execute existing proposals

## Data Model

### Vault-Level Data

Each vault maintains independent state:

```solidity
struct VaultInfo {
    uint256 id;              // Unique vault identifier
    string name;             // Human-readable name
    string metadataRef;      // IPFS or external metadata URI
    uint256 threshold;       // Minimum approval weight required
    uint256 totalWeight;     // Sum of all active signer weights
    uint256 signerCount;     // Number of active signers
    bool active;             // Vault status (true = active, false = archived)
}
```

**Signer Management** (per vault):
```solidity
mapping(uint256 vaultId => mapping(address => Signer)) vaultSigners;
mapping(uint256 vaultId => address[]) vaultSignerList;

struct Signer {
    address addr;
    uint256 weight;
    bool active;
}
```

**Vault-Specific Invariants**:
- `threshold > 0 && threshold <= totalWeight` (when threshold is set)
- `signerCount >= 1` (cannot remove last signer)
- `totalWeight == sum(signer.weight for all active signers)`

### Controller-Level Data

MultiVault contract manages:

**Vault Registry**:
```solidity
mapping(uint256 => VaultInfo) vaults;
uint256 vaultCount;  // Auto-incrementing vault ID
```

**Global Proposal Tracking**:
```solidity
struct Proposal {
    uint256 id;              // Global proposal ID
    uint256 vaultId;         // Which vault owns this proposal
    address recipient;
    uint256 amount;
    address token;
    bytes data;
    uint256 approvalWeight;  // Accumulated approval weight
    uint256 createdAt;
    uint256 expiresAt;
    bool executed;
    bool cancelled;
}

mapping(uint256 => Proposal) proposals;
mapping(uint256 proposalId => mapping(address => bool)) hasApproved;
uint256 proposalCount;
```

**Controller Settings**:
```solidity
uint256 proposalExpirationPeriod;  // Default: 30 days
address owner;  // UUPS proxy owner
```

## Configuration Change Rules

### Mid-Life Configuration Changes

Configuration changes take effect immediately but do **not retroactively affect existing proposals**:

| Operation | Effect on `totalWeight` | Effect on Existing Approvals |
|-----------|------------------------|------------------------------|
| `addSigner` | Increases | No change |
| `removeSigner` | Decreases | No change (approval weight preserved) |
| `updateSignerWeight` | Updates | No change (approval weight preserved) |
| `setThreshold` | No change | No change (may affect executability) |

### Examples

**Scenario 1: Threshold Change**
```solidity
// Initial: threshold = 200, signer1 (weight 100) approved proposal
// Change: owner sets threshold = 150
// Result: Proposal can now be executed with just signer1's approval
```

**Scenario 2: Signer Removal**
```solidity
// Initial: threshold = 200, signer1 + signer2 approved (100 + 100 = 200)
// Change: owner removes signer1 (totalWeight becomes 100)
// Result: Proposal still has 200 approval weight, exceeds new totalWeight, executes successfully
```

**Scenario 3: Weight Update**
```solidity
// Initial: signer1 (weight 100) approved proposal
// Change: owner updates signer1 weight to 200
// Result: Proposal approval weight remains 100 (not updated retroactively)
```

### Constraints and Edge Cases

1. **Cannot Remove Last Signer**: Vaults must have `signerCount >= 1`
   ```solidity
   revert CannotRemoveLastSigner();
   ```

2. **Threshold Validity**: When setting threshold, `threshold <= totalWeight`
   - Removing signers or reducing weights may cause `threshold > totalWeight`
   - This is allowed (owner must manually adjust threshold)

3. **Removed Signers and Proposals**:
   - Removed signers cannot approve new or existing proposals
   - Their previous approvals remain valid and count toward execution

4. **Cross-Vault Independence**: Signers can have different weights in different vaults
   ```solidity
   vault.addSigner(vault1, alice, 100);
   vault.addSigner(vault2, alice, 300);
   // Alice has weight 100 in vault1, weight 300 in vault2
   ```

## Upgrade and Migration Considerations

### Storage Layout (UUPS Proxy Pattern)

**OpenZeppelin Upgradeable Contracts** (slots 0-99):
- `Ownable`, `ReentrancyGuard`, `UUPS` base storage

**MultiVault Storage** (slots 100-149):
- `proposals`, `hasApproved`, `proposalCount`, `proposalExpirationPeriod`
- `vaults`, `vaultSigners`, `vaultSignerList`, `vaultCount`

**Reserved for Future** (slots 150-199):
- `__gap[50]` reserved for future controller-level features:
  - Cross-vault policies (e.g., global spending limits)
  - Fee collection or treasury management
  - Batch operations or vault grouping

### Upgrade Rules

1. **No Immutables**: All state variables use storage (upgradeable pattern)
2. **Storage Append-Only**: New variables must be added after existing ones or use `__gap`
3. **Initialization**: Use `initializer` modifier; reinitializers not supported in v1

### Adding New Features

**Example: Add global spending limit**
```solidity
// Reserve slot from __gap
uint256 public globalSpendingLimit;
uint256[49] private __gap;  // Reduced from 50 to 49

// Upgrade logic
function setGlobalSpendingLimit(uint256 limit) external onlyOwner {
    globalSpendingLimit = limit;
}
```

## Integration Guidelines

### For Integrators

**Reading Vault State**:
```solidity
IMultiVault.VaultInfo memory vault = multiVault.getVaultInfo(vaultId);
IMultiVault.Signer memory signer = multiVault.getSignerInfo(vaultId, address);
IMultiVault.Proposal memory proposal = multiVault.getProposal(proposalId);
```

**Creating and Approving Proposals**:
```solidity
// Only vault signers can create proposals
uint256 proposalId = multiVault.createProposal(
    vaultId,
    recipient,
    amount,
    token,
    data  // Optional calldata for contract interactions
);

// Signers approve (weight accumulates)
multiVault.approveProposal(proposalId);

// Anyone can execute once threshold met
multiVault.executeProposal(proposalId);
```

**Event Monitoring**:
- `VaultCreated(vaultId, name, metadataRef)`
- `VaultSignerAdded(vaultId, signer, weight)`
- `VaultSignerRemoved(vaultId, signer)`
- `VaultSignerWeightUpdated(vaultId, signer, oldWeight, newWeight)`
- `VaultThresholdUpdated(vaultId, oldThreshold, newThreshold)`
- `VaultArchived(vaultId)`
- `ProposalCreated(proposalId, vaultId, recipient, amount)`
- `ProposalApproved(proposalId, approver, weight, totalWeight)`
- `ProposalExecuted(proposalId, recipient, amount)`
- `ProposalCancelled(proposalId, cancelledBy)`

### For Auditors

**Security Considerations**:

1. **Reentrancy Protection**: All proposal execution paths use `nonReentrant`
2. **Access Control**:
   - Owner-only: `createVault`, `addSigner`, `removeSigner`, `setThreshold`, `updateSignerWeight`, `archiveVault`, `cancelProposal`
   - Signer-only: `createProposal`, `approveProposal`
   - Anyone: `executeProposal` (if threshold met)

3. **Approval Weight Immutability**: Once a signer approves, their weight is locked in `proposal.approvalWeight`
   - Configuration changes (remove signer, update weight) do not affect existing approval weights
   - This prevents retroactive manipulation of proposal outcomes

4. **Threshold Bypass Risk**: Removing signers can create scenario where `totalWeight < threshold`
   - Proposals with `approvalWeight >= threshold` can still execute
   - Owner must monitor and adjust thresholds when removing signers

5. **Expiration**: Proposals expire after `proposalExpirationPeriod` (default 30 days)
   - Expired proposals cannot be approved or executed

## Contract References

- **Main Contract**: `src/MultiVault.sol`
- **Interface**: `src/interfaces/IMultiVault.sol`
- **Tests**:
  - Vault lifecycle: `test/VaultLifecycle.t.sol`
  - Configuration changes: `test/ConfigurationChanges.t.sol`
  - Vault management: `test/VaultManagement.t.sol`

## Deployments

- **Base Mainnet**: `0xB4FD2402c97c0F2E38B3Be91596aDe8927A36439`
- **Base Sepolia**: `0xB4FD2402c97c0F2E38B3Be91596aDe8927A36439`

For upgrade history and deployment scripts, see `deployments/` and `script/` directories.
