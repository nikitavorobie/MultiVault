# MultiVault

A DAO-oriented treasury and multi-signature payout protocol built on Base with upgradeable smart contracts.

## Features

- **Multi-Vault Architecture**: Create and manage multiple independent treasury vaults
- **Per-Vault Governance**: Each vault has its own signers, weights, and thresholds
- **Vault Metadata**: Attach names and IPFS references to vault configurations
- **Weighted Multi-Sig**: Role-based weights for flexible governance
- **Threshold Approvals**: M-of-N signature requirements per vault
- **Proposal Lifecycle**: Create → Approve → Execute → Cancel
- **Programmable Payouts**: One-time, vesting, and streaming payments
- **Base Pay Integration**: Native USDC transfers on Base
- **Upgradeable Contracts**: UUPS proxy pattern for seamless updates
- **Storage Gaps**: Reserved slots for future feature additions

## Architecture

### Vault Management
Create isolated treasury vaults with independent governance:
```solidity
uint256 vaultId = multiVault.createVault("DAO Treasury", "ipfs://...");
multiVault.addSigner(vaultId, signer1, 100);
multiVault.addSigner(vaultId, signer2, 150);
multiVault.setThreshold(vaultId, 200);
```

## Contracts

- `MultiVault.sol`: Core multi-vault system with per-vault signer management
- `PayoutExecutor.sol`: Handles programmable payment schedules
- `BasePayIntegration.sol`: Base Pay USDC transfer integration

## Deployment

Deploy to Base Sepolia:
```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

## Testing

```bash
forge test -vvv
```

## Security

All contracts use OpenZeppelin upgradeable patterns and include:
- Reentrancy protection
- Access control
- SafeERC20 for token transfers

## License

MIT
