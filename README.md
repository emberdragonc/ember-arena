# 🏟️ Ember Arena v2

Decentralized idea voting for autonomous builds. Stake $EMBER on ideas you believe in - highest-staked idea wins automatically.

## How It Works

### Round Structure (2 days)

```
DAY 1: Submissions (24h)
├─ Submit ideas (100K EMBER fee)
└─ Ideas stored on-chain with metadata

DAY 2: Voting (24h)
├─ Back ideas with $EMBER (your stake = your vote)
├─ More backing = more likely to win
└─ Anyone can boost the prize pool

AUTO-RESOLVE: After voting ends
├─ Anyone calls resolveRound()
├─ Highest-backed idea wins (ties split pot)
└─ Fully trustless - no admin picks winners

PAYOUTS:
├─ 90% to winner backers (proportional to stake)
└─ 10% BURNED 🔥
```

### Example

- 5 ideas submitted
- $10,000 EMBER total backing across all ideas
- Idea A wins (had highest backing at $3,000)
- Idea A backers split $9,000 (3x return!)
- $1,000 burned

## Key Features

- **Trustless Resolution**: No owner can pick winners - highest stake wins automatically
- **Anyone Can Resolve**: Call `resolveRound()` after voting ends
- **Boost Pool**: Anyone can add EMBER to increase prizes
- **Tie Breaking**: Multiple winners split the pot equally
- **Refund Timeout**: 7-day safety net if round isn't resolved

## Contracts

| Contract | Address (Base Sepolia) |
|----------|------------------------|
| EmberArena | `0xcB1Aa33b4f8f4E2e113C3c41c92e59DF9Bfe6e9c` |
| MockEMBER | `0xFd3F1cbd832127f878803Bdbf0e51d7C87C75b34` |

## Security

- ✅ ReentrancyGuard on all state-changing functions
- ✅ SafeERC20 for token transfers
- ✅ Pausable for emergencies
- ✅ Ownable2Step for ownership (admin functions only)
- ✅ Pull payment pattern
- ✅ CEI (Checks-Effects-Interactions) throughout
- ✅ Anti-spam: 100K EMBER submission fee
- ✅ Anti-dust: 0.01 EMBER minimum backing
- ✅ Anti-DoS: 100 max ideas per round

## Audit Status

- ✅ 3-pass self-audit complete
- ✅ Dragon Bot Z external audit: PASSED
- ✅ Tests: 49/49 passing

## Development

```bash
# Install
forge install

# Build
forge build

# Test
forge test

# Deploy (Base Sepolia)
forge script script/DeployEmberArena.s.sol --rpc-url base-sepolia --broadcast
```

## Integration with Ember Ecosystem

- **Idea Creators**: 50% of app fees from their winning ideas
- **Backers**: Profit from backing winning ideas
- **Burns**: 10% of every round creates deflationary pressure

## License

MIT
