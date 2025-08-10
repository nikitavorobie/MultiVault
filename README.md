# MultiVault

A DAO-oriented multi-signature payout system built on Base with upgradeable smart contracts.

## Features

- **Multi-Signer Architecture**: Role-based weights for flexible governance
- **Threshold Approvals**: M-of-N signature requirements
- **Proposal Lifecycle**: Create → Approve → Execute → Cancel
- **Programmable Payouts**: One-time, vesting, and streaming payments
- **Base Pay Integration**: Native USDC transfers on Base
- **Upgradeable Contracts**: UUPS proxy pattern for seamless updates

## Contracts

- `MultiVault.sol`: Core multi-sig vault with proposal management
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
