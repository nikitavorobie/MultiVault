# Deployment Metadata

This directory contains deployment information for each network deployment.

## Structure

Each deployment is stored in a JSON file named after the network:
- `base-mainnet.json` - Base Mainnet deployment
- `base-sepolia.json` - Base Sepolia testnet deployment

## Format

```json
{
  "network": "base-mainnet",
  "chainId": 8453,
  "contracts": {
    "MultiVault": {
      "proxy": "0x...",
      "implementation": "0x...",
      "deployer": "0x...",
      "deployedAt": "2024-11-20T...",
      "verified": true
    }
  },
  "upgrades": []
}
```

## Upgrades

Each upgrade appends to the `upgrades` array:

```json
{
  "version": "v0.2.0",
  "implementation": "0x...",
  "upgradedAt": "2024-12-02T...",
  "changes": ["Added multi-vault support", "Per-vault signer management"]
}
```
