# MultiVault

Multi-signature treasury protocol for DAOs on Base. Manage multiple independent vaults with weighted approvals and programmable payouts.

## Overview

MultiVault enables DAOs and teams to create isolated treasury vaults with customizable governance. Each vault maintains its own signers, voting weights, and approval thresholds.

## Key Features

- **Multiple Vaults**: Create unlimited independent treasuries
- **Weighted Voting**: Assign different voting power to signers
- **Flexible Thresholds**: Set custom approval requirements per vault
- **Programmable Payouts**: One-time, vesting, and streaming payments
- **USDC Transfers**: Native Base Pay integration
- **Fully Upgradeable**: UUPS proxy pattern

## Use Cases

### DAO Treasury Management
```solidity
// Create DAO treasury vault
uint256 daoVault = multiVault.createVault(
    "DAO Treasury",
    "ipfs://QmMetadata..."
);

// Add council members with weights
multiVault.addSigner(daoVault, member1, 100);  // 100 votes
multiVault.addSigner(daoVault, member2, 150);  // 150 votes
multiVault.addSigner(daoVault, member3, 200);  // 200 votes

// Set threshold (need 300+ votes to execute)
multiVault.setThreshold(daoVault, 300);
```

### Multi-Department Budgets
```solidity
// Separate vaults for different teams
uint256 devFund = multiVault.createVault("Development", "ipfs://...");
uint256 marketingFund = multiVault.createVault("Marketing", "ipfs://...");
uint256 grantsFund = multiVault.createVault("Grants", "ipfs://...");

// Each vault has independent signers and rules
```

### Contributor Payroll
```solidity
// Create proposal for payment
uint256 proposalId = multiVault.createProposal(
    contributor,
    5000 * 1e6,  // 5000 USDC
    USDC_ADDRESS,
    ""
);

// Signers approve
multiVault.approveProposal(proposalId);

// Execute when threshold met
multiVault.executeProposal(proposalId);
```

## Deployed Contracts

**Base Mainnet:**
- MultiVault: `0xB4FD2402c97c0F2E38B3Be91596aDe8927A36439`
- PayoutExecutor: `0x5828179353Ad884B10f40Be9122747e1415d7Ea1`

**Base Sepolia:**
- MultiVault: `0xB4FD2402c97c0F2E38B3Be91596aDe8927A36439`
- PayoutExecutor: `0x5828179353Ad884B10f40Be9122747e1415d7Ea1`

## Core Functions

### Vault Management
```solidity
createVault(string name, string metadataRef) returns (uint256 vaultId)
addSigner(uint256 vaultId, address signer, uint256 weight)
removeSigner(uint256 vaultId, address signer)
setThreshold(uint256 vaultId, uint256 threshold)
```

### Proposals
```solidity
createProposal(address recipient, uint256 amount, address token, bytes data) returns (uint256)
approveProposal(uint256 proposalId)
executeProposal(uint256 proposalId)
cancelProposal(uint256 proposalId)
```

### Payouts
```solidity
createOneTimePayout(address recipient, address token, uint256 amount)
createVestingPayout(address recipient, address token, uint256 amount, uint256 duration, uint256 cliff)
createStreamingPayout(address recipient, address token, uint256 amount, uint256 duration)
```

## License

MIT
