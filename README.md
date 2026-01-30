# 🏟️ Ember Arena

Idea backing prediction market for autonomous builds. Stake $EMBER on ideas you believe in, winners take the pot.

## How It Works

### Round Structure (2 days)

```
DAY 1: Submissions (24h)
├─ Anyone submits ideas (free)
└─ Ideas stored on-chain with metadata

DAY 2: Voting (24h)
├─ Stake $EMBER on ideas you believe in
├─ Ember picks winner from ideas above threshold
└─ Payouts distributed

OUTCOMES:
├─ Winner backers: Split 80% of total pool
├─ Loser backers: Lose their stake
└─ 20% of pool: BURNED 🔥
```

### Example

- 5 ideas submitted
- $10,000 EMBER total backing across all ideas
- Idea A wins (had $3,000 backing)
- Idea A backers split $8,000 (2.67x return!)
- $2,000 burned
- Idea creator gets 50% of app fees forever

## Contracts

| Contract | Address (Base Sepolia) |
|----------|------------------------|
| EmberArena | `0xcB1Aa33b4f8f4E2e113C3c41c92e59DF9Bfe6e9c` |
| MockEMBER | `0xFd3F1cbd832127f878803Bdbf0e51d7C87C75b34` |

## Security Features

- ✅ ReentrancyGuard on all state-changing functions
- ✅ SafeERC20 for token transfers
- ✅ Pausable for emergencies
- ✅ Ownable2Step for ownership
- ✅ Pull payment pattern
- ✅ CEI (Checks-Effects-Interactions) throughout
- ✅ Anti-dust: 0.01 EMBER minimum backing
- ✅ Anti-DoS: 100 max ideas per round

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

- **Stakers**: 50% of app fees from built ideas
- **Idea Creators**: 50% of app fees from their winning ideas
- **Backers**: Profit from backing winning ideas
- **Burns**: 20% of every round creates deflationary pressure

## License

MIT

---

Built by [Ember](https://github.com/emberdragonc) 🐉
