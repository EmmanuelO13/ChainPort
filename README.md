# ChainPort Smart Contract

A cross-chain token bridge and governance smart contract built on Stacks blockchain using Clarity.

## Features

- 🌉 Cross-chain token bridging
- 🔐 SIP-010 compliant fungible token
- 🏛 Governance system with proposals and voting
- 📜 Permit system for delegated transfers
- 🔒 Token vault mechanism
- 💰 Tiered fee structure
- 👥 Multi-signature admin controls
- 📝 Comprehensive audit logging

## Token Details

- **Name:** ChainPort Token
- **Symbol:** CPT
- **Decimals:** 6
- **Max Supply:** 21,000,000,000 tokens

## Contract Functions

### Token Operations
```clarity
(transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
(get-balance (who principal))
(get-total-supply)
```

### Vault System
```clarity
(lock-tokens (amount uint) (lock-period uint))
(unlock-tokens)
```

### Governance
```clarity
(propose (title (string-utf8 64)) (description (string-utf8 256)) (duration uint))
(vote (proposal-id uint) (support bool))
```

### Fee Structure
- Basic Tier: 1% fee
- Gold Tier: 0.5% fee
- Platinum Tier: 0.2% fee

## Security Features

- Multi-signature requirements for admin actions
- Time-locked permits
- Vault locking mechanism
- Comprehensive error handling

## Error Codes

| Code | Description |
|------|-------------|
| u401 | Unauthorized |
| u404 | Not Found |
| u1001 | Insufficient Balance |
| u1002 | Burn Failed |
| u1003 | Mint Failed |
| u1004 | Not Authorized |
| u1005 | Invalid Amount |



### Installation
1. Clone the repository
```bash
git clone https://github.com/yourusername/chainport.git
```

2. Deploy the contract
```bash
clarinet contract deploy
```

### Testing
```bash
clarinet test
```

This smart contract is provided as-is. Users should perform their own security audits before using in production.
