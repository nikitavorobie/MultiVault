# Governance Patterns for MultiVault

This document provides recommended governance patterns for different organizational types using MultiVault. Each pattern includes role assignment strategies, security considerations, and operational workflows.

## Overview

MultiVault implements a flexible role-based access control system that can accommodate various governance models. The system provides four main role categories:

- **GLOBAL_ADMIN** (DEFAULT_ADMIN_ROLE): Controller-level administration
- **VAULT_ADMIN**: Vault-specific configuration management
- **OPERATOR**: Routine payout execution
- **PAUSER**: Emergency circuit breaker

## Pattern 1: DAO Treasury

### Recommended Configuration

```
GLOBAL_ADMIN: DAO Governance Contract (Governor + Timelock, 48h delay)
VAULT_ADMIN (core treasury): Community Multisig (5-of-9)
VAULT_ADMIN (grants fund): Grants Committee Multisig (3-of-5)
VAULT_ADMIN (ops fund): Operations Committee Multisig (2-of-3)
OPERATOR: Treasury Automation Bot + Emergency Override Multisig (2-of-3)
PAUSER: Security Response Team Multisig (3-of-5, no timelock)
```

### Implementation Example

```solidity
// Deploy MultiVault
MultiVault vault = ...;

// Set GLOBAL_ADMIN to Governor contract
vault.grantRole(DEFAULT_ADMIN_ROLE, governorAddress);
vault.renounceRole(DEFAULT_ADMIN_ROLE, deployer);

// Create vaults and assign vault admins
uint256 coreTreasuryId = vault.createVault("Core Treasury", "ipfs://...");
vault.grantRole(vault.getVaultAdminRole(coreTreasuryId), communityMultisig);

uint256 grantsFundId = vault.createVault("Grants Fund", "ipfs://...");
vault.grantRole(vault.getVaultAdminRole(grantsFundId), grantsCommittee);

// Assign operational roles
vault.grantRole(OPERATOR_ROLE, treasuryBot);
vault.grantRole(OPERATOR_ROLE, emergencyMultisig);
vault.grantRole(PAUSER_ROLE, securityTeam);
```

### Security Considerations

1. **Timelock for Critical Operations**
   - All GLOBAL_ADMIN actions go through 48h timelock
   - Emergency pause bypasses timelock via PAUSER role

2. **Separation of Powers**
   - Vault admins cannot modify other vaults
   - Operators execute but cannot configure
   - Pausers can only halt, not modify state

3. **Key Management**
   - Store multisig keys in hardware wallets
   - Use different signers for different roles
   - Document key recovery procedures

### Operational Workflow

**Creating a Payout:**
1. Contributor creates proposal through DAO UI
2. Vault signers approve proposal (weighted voting)
3. Once threshold met, operator executes payout
4. Execution creates payout in PayoutExecutor (vesting/streaming)
5. Recipient claims according to schedule

**Emergency Response:**
1. Security team detects exploit/vulnerability
2. PAUSER executes immediate pause
3. Team investigates and prepares fix
4. If upgrade needed: deploy new implementation
5. GLOBAL_ADMIN executes upgrade (after timelock)
6. PAUSER unpauses after verification

## Pattern 2: Company Treasury

### Recommended Configuration

```
GLOBAL_ADMIN: Board Multisig (5-of-7 directors)
VAULT_ADMIN (development): CTO
VAULT_ADMIN (operations): COO
VAULT_ADMIN (marketing): CMO
OPERATOR: Finance Team Members (individual accounts)
PAUSER: CTO + Security Lead Multisig (2-of-2)
```

### Implementation Example

```solidity
// Centralized deployment by CEO/CFO
vault.grantRole(DEFAULT_ADMIN_ROLE, boardMultisig);

// Department vaults with single-admin model
uint256 devFundId = vault.createVault("Development Fund", "");
vault.grantRole(vault.getVaultAdminRole(devFundId), ctoAddress);

// Add signers to department vault
vm.startPrank(ctoAddress);
vault.addSigner(devFundId, techLead1, 100);
vault.addSigner(devFundId, techLead2, 100);
vault.setThreshold(devFundId, 100); // Require 1-of-2
vm.stopPrank();

// Operational access for finance team
vault.grantRole(OPERATOR_ROLE, financeManager);
vault.grantRole(OPERATOR_ROLE, accountant);
```

### Security Considerations

1. **Hierarchical Control**
   - Board controls protocol upgrades and vault creation
   - Department heads control their vault configuration
   - Finance team executes approved payouts

2. **Audit Trail**
   - All role changes emit events
   - Monitor role grants/revocations
   - Regular access reviews (quarterly)

3. **Business Continuity**
   - Document role assignment procedures
   - Maintain backup admin access (board multisig)
   - Test emergency pause quarterly

### Operational Workflow

**Monthly Payroll:**
1. Finance prepares payroll proposals for each department vault
2. Department signers review and approve
3. Finance operator executes batch payouts
4. Vesting schedules for equity compensation

**Vendor Payment:**
1. Department head creates proposal with invoice data
2. Department signers approve (may require 2-of-3 for large amounts)
3. Finance verifies invoice and executes
4. One-time payment to vendor address

## Pattern 3: Hybrid Model (Foundation + DAO)

### Recommended Configuration

```
GLOBAL_ADMIN: Timelocked DAO Governance (72h delay)
VAULT_ADMIN (foundation): Foundation Board Multisig (3-of-5)
VAULT_ADMIN (community): Community Multisig (7-of-11)
VAULT_ADMIN (grants): Independent Grants Committee (5-of-7)
OPERATOR: Automated Scheduler + Manual Override (foundation 2-of-3)
PAUSER: Combined Security Team (foundation + community, 4-of-7)
```

### Implementation Example

```solidity
// Split control between foundation and community
vault.grantRole(DEFAULT_ADMIN_ROLE, daoGovernor);

// Foundation vault (centralized but transparent)
uint256 foundationId = vault.createVault("Foundation Treasury", "ipfs://...");
vault.grantRole(vault.getVaultAdminRole(foundationId), foundationBoard);

// Community vault (decentralized)
uint256 communityId = vault.createVault("Community Treasury", "ipfs://...");
vault.grantRole(vault.getVaultAdminRole(communityId), communityMultisig);

// Shared security response
vault.grantRole(PAUSER_ROLE, foundationSecurityLead);
vault.grantRole(PAUSER_ROLE, communitySecurityLead);
vault.grantRole(PAUSER_ROLE, independentAuditor);
```

### Security Considerations

1. **Gradual Decentralization**
   - Foundation vault for operational stability
   - Community vault for ecosystem funding
   - DAO governance for protocol changes

2. **Checks and Balances**
   - Neither foundation nor community controls global admin alone
   - Emergency pause requires cooperation (4-of-7)
   - Transparent on-chain governance

3. **Progressive Trust**
   - Start with foundation-heavy control
   - Gradually increase community multisig weight
   - Eventually transition to full DAO control

### Operational Workflow

**Ecosystem Grant:**
1. Applicant submits grant proposal to DAO
2. Grants committee evaluates and creates payout proposal
3. Community signers approve
4. Operator executes vesting schedule
5. Monthly releases over grant duration

**Protocol Upgrade:**
1. Foundation or community proposes upgrade
2. DAO governance vote (7-day period)
3. If passed: 72h timelock begins
4. After timelock: GLOBAL_ADMIN executes upgrade
5. Monitor for issues; PAUSER available if needed

## Pattern 4: Multi-Project Allocation

### Recommended Configuration

For organizations managing multiple independent projects from one treasury:

```
GLOBAL_ADMIN: Core Team Multisig (3-of-5)
VAULT_ADMIN (project A): Project A Lead
VAULT_ADMIN (project B): Project B Lead
VAULT_ADMIN (project C): Project C Lead
OPERATOR: Shared Finance Coordinator
PAUSER: Core Team Security Officer
```

### Implementation Example

```solidity
// Allocate budgets to project leads
uint256 projectA = vault.createVault("Project Alpha", "");
vault.addSigner(projectA, projectALead, 100);
vault.setThreshold(projectA, 100);
vault.grantRole(vault.getVaultAdminRole(projectA), projectALead);

// Project lead can manage their team
vm.startPrank(projectALead);
vault.addSigner(projectA, developer1, 50);
vault.addSigner(projectA, developer2, 50);
vault.setThreshold(projectA, 100); // Require lead OR 2 developers
vm.stopPrank();
```

### Operational Workflow

**Budget Allocation:**
1. Core team creates vault for new project
2. Assign project lead as VAULT_ADMIN
3. Project lead configures signers (team members)
4. Core team funds vault with allocated budget

**Project Spending:**
1. Team creates payment proposals within their vault
2. Signers approve according to vault threshold
3. Finance coordinator (OPERATOR) executes
4. Core team monitors spending via events

## Best Practices

### Role Assignment

1. **Principle of Least Privilege**
   - Grant minimum necessary permissions
   - Review and revoke unused roles regularly
   - Use time-bound roles where possible (through off-chain coordination)

2. **Separation of Duties**
   - Don't combine GLOBAL_ADMIN and OPERATOR in same account
   - Use different multisigs for different roles
   - Ensure no single person controls multiple critical roles

3. **Key Security**
   - Hardware wallets for all multisig signers
   - Secure backup of recovery phrases
   - Regular key rotation (annually minimum)

### Operational Security

1. **Monitoring**
   - Subscribe to role change events
   - Alert on unexpected pause/unpause
   - Track proposal approval patterns

2. **Testing**
   - Test pause mechanism quarterly
   - Dry-run upgrade procedures
   - Verify backup admin access

3. **Documentation**
   - Maintain updated role assignment records
   - Document emergency procedures
   - Record all governance decisions

### Incident Response

1. **Detection**
   - Monitor for unusual transactions
   - Watch for unexpected role changes
   - Alert on large payouts

2. **Response**
   - PAUSER executes immediate pause
   - Security team investigates
   - Prepare and test fix

3. **Recovery**
   - Deploy fix (if needed)
   - Execute upgrade via GLOBAL_ADMIN
   - Unpause after verification
   - Post-mortem and process improvement

## Migration from Simple Ownership

If you currently use Ownable pattern and want to migrate:

1. **Deploy new implementation with AccessControl**
2. **Keep current owner as DEFAULT_ADMIN initially**
3. **Gradually assign specialized roles:**
   - Create vault admins for department/committee
   - Assign operators for routine tasks
   - Set up pauser for emergency response
4. **Test thoroughly on testnet first**
5. **Execute upgrade on mainnet**
6. **Optionally renounce DEFAULT_ADMIN to multisig/governance**

## Tools and Resources

- **Multisig:** Safe (formerly Gnosis Safe)
- **Governance:** OpenZeppelin Governor + Timelock
- **Monitoring:** Tenderly, OpenZeppelin Defender
- **Testing:** Foundry fork testing
- **Auditing:** Engage security firm before mainnet deployment

## Support

For questions or custom governance patterns:
- Review role system documentation: `docs/ROLE_SYSTEM.md`
- Check test examples: `test/RoleSystem.t.sol`
- Open issue: https://github.com/nikitavorobie/MultiVault/issues
