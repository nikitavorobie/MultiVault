# Role System Design

## Role Hierarchy

### 1. GLOBAL_ADMIN (DEFAULT_ADMIN_ROLE)
**Purpose**: Controller-level administration and emergency operations

**Permissions**:
- Create and archive vaults
- Upgrade contracts (UUPS)
- Emergency pause/unpause
- Cancel proposals (emergency intervention)
- Grant/revoke VAULT_ADMIN roles to vault owners
- Grant/revoke OPERATOR roles
- Grant/revoke PAUSER roles

**Typical holders**:
- DAO governance contract
- Multi-sig of core team
- Timelock contract

### 2. VAULT_ADMIN (per-vault dynamic role)
**Purpose**: Manage specific vault configuration

**Role ID**: `keccak256(abi.encodePacked("VAULT_ADMIN", vaultId))`

**Permissions** (vault-specific):
- Add/remove signers in their vault
- Update signer weights in their vault
- Set approval threshold in their vault

**Restrictions**:
- Cannot affect other vaults
- Cannot create or archive vaults
- Cannot upgrade contracts
- Cannot pause system

**Typical holders**:
- Vault creator/owner
- Department head (for company treasury)
- Sub-DAO governance (for DAO treasury)

### 3. OPERATOR
**Purpose**: Execute approved operations without admin privileges

**Permissions**:
- Execute proposals that meet threshold
- Execute payouts (in PayoutExecutor)

**Restrictions**:
- Cannot modify vault configuration
- Cannot create or approve proposals
- Cannot cancel proposals

**Typical holders**:
- Automated bots
- Treasury managers
- Finance team members

### 4. PAUSER
**Purpose**: Emergency circuit breaker

**Permissions**:
- Pause contract operations
- Unpause contract operations

**Restrictions**:
- Cannot perform any other operations

**Typical holders**:
- Security multisig
- Monitoring bots with pause authority
- Core team emergency responders

## Access Control Matrix

| Operation | GLOBAL_ADMIN | VAULT_ADMIN<br/>(own vault) | OPERATOR | Signer | Anyone |
|-----------|:------------:|:---------------------------:|:--------:|:------:|:------:|
| **Vault Management** |
| createVault | ✓ | - | - | - | - |
| archiveVault | ✓ | - | - | - | - |
| addSigner | ✓ | ✓ | - | - | - |
| removeSigner | ✓ | ✓ | - | - | - |
| updateSignerWeight | ✓ | ✓ | - | - | - |
| setThreshold | ✓ | ✓ | - | - | - |
| **Proposal Flow** |
| createProposal | - | - | - | ✓ | - |
| approveProposal | - | - | - | ✓ | - |
| executeProposal | ✓ | ✓ | ✓ | ✓ | ✓ |
| cancelProposal | ✓ | - | - | - | - |
| **Payout Management** |
| createPayout | MultiVault only | - | - | - | - |
| cancelPayout | MultiVault only | - | - | - | - |
| claimPayout | - | - | - | - | Recipient |
| **System Control** |
| pause | ✓ + PAUSER | - | - | - | - |
| unpause | ✓ + PAUSER | - | - | - | - |
| upgradeContract | ✓ | - | - | - | - |
| grantRole | ✓ | - | - | - | - |
| revokeRole | ✓ | - | - | - | - |

## Privilege Escalation Protection

### Cross-Vault Isolation
- VAULT_ADMIN of vault A cannot modify vault B
- Role checks include `vaultId` verification
- Each vault has independent admin role

### Role Hierarchy Enforcement
- Only GLOBAL_ADMIN can grant roles
- VAULT_ADMIN cannot self-promote to GLOBAL_ADMIN
- OPERATOR cannot modify vault configuration
- Role changes emit events for monitoring

### Signer vs Admin Separation
- Signers create and approve proposals (governance)
- Admins configure vault rules (administration)
- These are independent: signer ≠ admin

## Emergency Pause Behavior

### When Paused
**Blocked operations**:
- createVault
- addSigner, removeSigner, updateSignerWeight, setThreshold
- createProposal, approveProposal, executeProposal
- createPayout, claimPayout, cancelPayout

**Allowed operations**:
- View functions (read-only)
- unpause (by GLOBAL_ADMIN or PAUSER)

### Recovery Path
1. PAUSER or GLOBAL_ADMIN detects security issue
2. Call `pause()` to halt all operations
3. Investigate and fix issue (may require upgrade)
4. Call `unpause()` to resume normal operation

## Role Assignment Patterns

### DAO Treasury
```
GLOBAL_ADMIN: DAO governance contract (e.g., Governor + Timelock)
VAULT_ADMIN (vault 0): Core DAO multisig
VAULT_ADMIN (vault 1): Marketing committee multisig
OPERATOR: Treasury bot (automated execution)
PAUSER: Security multisig (3-of-5)
```

### Company Treasury
```
GLOBAL_ADMIN: Board multisig (5-of-7)
VAULT_ADMIN (dev fund): CTO
VAULT_ADMIN (ops fund): COO
OPERATOR: Finance team members
PAUSER: CTO + Security lead multisig
```

### Hybrid Model
```
GLOBAL_ADMIN: DAO governance + Timelock (48h delay)
VAULT_ADMIN (community vault): Community multisig
VAULT_ADMIN (foundation vault): Foundation board
OPERATOR: Automated scheduler + Manual override multisig
PAUSER: Fast-response security multisig (no timelock)
```

## Implementation Notes

### Role Initialization
- GLOBAL_ADMIN assigned to deployer in `initialize()`
- VAULT_ADMIN roles granted when vault is created (to creator or specified address)
- OPERATOR and PAUSER roles granted manually by GLOBAL_ADMIN

### Storage Layout
- Uses OpenZeppelin AccessControlUpgradeable (no extra storage needed)
- Uses OpenZeppelin PausableUpgradeable (1 bool in storage)
- Adjust `__gap` by -1 to accommodate pause state

### Events
- `RoleGranted(role, account, sender)`
- `RoleRevoked(role, account, sender)`
- `Paused(account)`
- `Unpaused(account)`
