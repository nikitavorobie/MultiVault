# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability within MultiVault, please send an email to security@multivault.example. All security vulnerabilities will be promptly addressed.

Please do not open public issues for security vulnerabilities.

## Security Considerations

- All contracts are upgradeable using UUPS pattern
- Multi-signature approval required for critical operations
- Proposal expiration prevents stale proposals
- Reentrancy protection on all state-changing functions
- SafeERC20 used for token transfers
