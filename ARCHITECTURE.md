# DiceFate Architecture & Design Document

## Executive Summary

DiceFate is a decentralized gambling dApp built on Ethereum that allows users to bet ETH on dice rolls with provably fair randomness powered by Chainlink VRF. The smart contract components are built and tested with Foundry, and the frontend is a React/Next.js web application with wallet integration.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    User Browser                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │         React Frontend (Next.js)                       │  │
│  │  - BettingForm: Bet placement UI                       │  │
│  │  - BetHistory: View placed bets                        │  │
│  │  - ContractInfo: Balance and game info                 │  │
│  │  - WalletConnect: RainbowKit integration              │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                             │
                             │ wagmi + ethers.js
                             │
┌─────────────────────────────────────────────────────────────┐
│              Blockchain (Local Anvil / Sepolia / Mainnet)    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │            DiceFate Smart Contract                  │    │
│  │  ┌──────────────────────────────────────────────┐   │    │
│  │  │ placeBet(targetNumber)                       │   │    │
│  │  │ - Receives ETH bet                           │   │    │
│  │  │ - Reserves payout from house balance         │   │    │
│  │  │ - Requests random number                     │   │    │
│  │  │ - Emits BetPlaced event                      │   │    │
│  │  └──────────────────────────────────────────────┘   │    │
│  │  ┌──────────────────────────────────────────────┐   │    │
│  │  │ resolveBet(betId, randomNumber)              │   │    │
│  │  │ - Calculates dice roll (randomNumber % 100)  │   │    │
│  │  │ - Determines win/loss                        │   │    │
│  │  │ - Pays winner 1.95x - 5% if winning         │   │    │
│  │  │ - Emits BetResolved event                    │   │    │
│  │  └──────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
│                              │                               │
│                              │ callback()                    │
│                              ▼                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │        MockVRFCoordinatorV2 (for local dev)        │    │
│  │  ┌──────────────────────────────────────────────┐   │    │
│  │  │ requestRandomWords()                         │   │    │
│  │  │ - Generated request ID                       │   │    │
│  │  │ - Maps request to consumer                   │   │    │
│  │  │ - Returns request ID                         │   │    │
│  │  └──────────────────────────────────────────────┘   │    │
│  │  ┌──────────────────────────────────────────────┐   │    │
│  │  │ fulfillRandomWords(requestId, randomWords)   │   │    │
│  │  │ - Calls consumer's rawFulfillRandomWords()   │   │    │
│  │  │ - Provides random values                     │   │    │
│  │  └──────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Smart Contract Design

### DiceFate.sol - Main Contract

**Functions:**

#### `placeBet(uint8 targetNumber) payable`

```
Input: targetNumber (2-100)
- Validates target range
- Checks sufficient house balance for payout
- Creates Bet struct with player address, amount, target
- Reserves payout amount from house balance
- Requests random number from VRF
- Emits BetPlaced event

Gas: ~95,000
Returns: betId (uint256)
```

**State Changes:**

- Maps bet ID to Bet struct
- Tracks bet ID for player
- Reduces contractBalance by reserved payout

#### `resolveBet(uint256 betId, uint256 randomNumber)`

```
Input: betId, randomNumber (0-99)
- Retrieves bet from storage
- Calculates roll: (randomNumber % 100) + 1
- Checks if roll < targetNumber
- If WIN:
  - Calculates payout: amount * 1.95 * 0.95
  - Transfers payout to player
  - Returns reserved balance to house
- If LOSE:
  - Returns reserved balance to house (keeps bet)
- Marks bet as resolved
- Emits BetResolved event

Gas: ~100,000-110,000
Owner Only: Yes
```

**Payout Calculation:**

```
Base payout = betAmount × 1.95       // 1.95x multiplier
After fee = basePayout × 0.95        // -5% house edge
Example: 1 ETH → 1.8525 ETH if win
```

**State Changes:**

- Updates Bet.resolved = true
- Updates Bet.won = true/false
- Updates Bet.rollResult
- Transfers ETH to player if winning
- Updates contractBalance

### House Balance Management

The contract maintains two key concepts:

1. **contractBalance**: Available + Reserved funds
2. **Reserved Funds**: Amount set aside for pending bets

**Flow:**

```
placeBet():
  contractBalance -= (betAmount * 1.95)  // Reserve

resolveBet() [WIN]:
  player += payout
  contractBalance += betAmount  // House keeps bet

resolveBet() [LOSE]:
  contractBalance += (betAmount * 1.95)  // Return reservation
```

### Events

**BetPlaced**

```solidity
event BetPlaced(
    uint256 indexed betId,
    address indexed player,
    uint256 amount,
    uint8 targetNumber,
    uint256 requestId
);
```

**BetResolved**

```solidity
event BetResolved(
    uint256 indexed betId,
    address indexed player,
    uint256 rollResult,
    bool won,
    uint256 payout
);
```

## Game Mechanics

### Win Probability

For target number N (2-100):

```
Formula: P(win) = (N - 1) / 100

Examples:
- Target 2:   1% win chance
- Target 50: 49% win chance
- Target 75: 74% win chance
- Target 100: 99% win chance
```

### Expected Value for Player

```
EV = (winPayout × P(win)) - (betAmount × P(loss))
EV = (betAmount × 1.95 × 0.95 × P(win)) - (betAmount × (1 - P(win)))
EV = (betAmount × 1.8525 × P(win)) - (betAmount × (1 - P(win)))

For P(win) = 0.49 (target 50):
EV = (bet × 1.8525 × 0.49) - (bet × 0.51)
EV = (bet × 0.9077) - (bet × 0.51)
EV = bet × (-0.0623) = -6.23% house advantage
```

### Dice Roll Calculation

```
Roll = (randomNumber % 100) + 1
Range: 1-100

Examples:
- randomNumber = 0   → roll = 1
- randomNumber = 42  → roll = 43
- randomNumber = 99  → roll = 100
```

Win condition: `roll < targetNumber`

## Frontend Architecture

### Component Hierarchy

```
app/page.tsx (Main Page)
├── WalletConnect
├── BettingForm
│   └── Displays probability
│   └── Calculates expected value
│   └── Handles bet submission
├── ContractInfo
│   ├── User balance
│   ├── House balance
│   └── Game rules
└── BetHistory
    └── BetRow (for each bet)
        └── Displays resolved/pending status
```

### State Management

**wagmi Hooks:**

- `useAccount()`: Current connected wallet
- `useBalance()`: ETH balance
- `useReadContract()`: Read contract state
- `useWriteContract()`: Execute contract functions

**Custom Hooks (lib/hooks.ts):**

- `useDiceFate()`: Aggregates all contract interactions

### Data Flow

```
User Input
    ↓
BettingForm.handlePlaceBet()
    ↓
useDiceFate().placeBet()
    ↓
useWriteContract() → wagmi
    ↓
ethers.js
    ↓
MetaMask/Wallet
    ↓
Blockchain Transaction
    ↓
BetPlaced Event
    ↓
useReadContract() polls
    ↓
UI Updates
```

## Testing Strategy

### Unit Tests (test/DiceFate.t.sol)

**Categories:**

1. **Bet Placement**
   - Valid bet creation
   - Invalid target numbers
   - Zero bet rejection
   - House balance validation

2. **Bet Resolution**
   - Winning bets with correct payouts
   - Losing bets (house keeps)
   - Edge cases (roll exactly 100)

3. **House Management**
   - Deposit functionality
   - Withdraw functionality
   - Balance tracking

4. **Integration**
   - Multiple players
   - Multiple bets per player
   - Concurrent resolutions

### Test Coverage

```
File: DiceFate.sol
├── placeBet() ........ ✓
├── resolveBet() ...... ✓ (win/loss paths)
├── depositHouse() .... ✓
├── withdrawHouse() ... ✓
├── getPlayerBets() ... ✓
├── getBet() ......... ✓
└── receive() ........ ✓
Coverage: ~95%
Gas Report: Available
```

### Test Execution

```bash
# All tests
forge test -v

# With gas report
forge test --gas-report

# Specific test
forge test --match testResolveBetWin -vvv

# Watch mode
forge test --watch
```

## Deployment Architecture

### Local Development (Anvil)

```
+─────────────────────+
│  Frontend (3000)    │ ← User
+─────────────────────+
         ↓
+─────────────────────+
│  MetaMask/Wallet    │
+─────────────────────+
         ↓
+─────────────────────+
│  Anvil (8545)       │ ← RPC
├─────────────────────┤
│  MockVRFCoordinator │
│  DiceFate           │
+─────────────────────+
```

### Testnet Deployment (Sepolia)

```
Frontend (Vercel)
      ↓
MetaMask (Testnet)
      ↓
Alchemy/Infura RPC
      ↓
Chainlink VRF Sepolia
      ↓
DiceFate Contract
      ↓
Real VRF Callback
```

### Production Deployment (Mainnet)

```
Frontend (Production)
      ↓
MetaMask (Mainnet)
      ↓
Multiple RPC Providers
      ↓
Chainlink VRF Mainnet
      ↓
DiceFate Contract
      ↓
Real VRF with
Subscription
```

## Security Considerations

### Smart Contract

1. **House Balance Validation**
   - Prevents over-promising payouts
   - Checked before accepting bets

2. **Access Control**
   - `resolveBet()` is owner-only
   - Prevents arbitrary bet resolution
   - Future: Implement automated callback

3. **Randomness Source**
   - Chainlink VRF for production
   - Cryptographically secure
   - Verifiable proofs

4. **Reentrancy Protection**
   - Uses transfer (not call) for payments
   - No callback post-transfer
   - Safe against reentrancy

### Frontend

1. **Wallet Security**
   - RainbowKit handles key management
   - Never stores private keys
   - User-managed through MetaMask

2. **Contract Interaction**
   - ABI validation
   - Contract address verification
   - Transaction confirmation prompts

3. **Input Validation**
   - Range validation (2-100)
   - Amount validation (>0)
   - User balance checking

### Deployment

1. **Private Key Management**
   - Never committed to repo
   - Environment variables only
   - Rotate after deployment

2. **Gas Limits**
   - Set appropriately for each function
   - Monitored in tests
   - Optimized for cost efficiency

## Performance Characteristics

### Gas Usage

```
Function             Average Gas    Cost at 20 gwei
─────────────────────────────────────────────────
placeBet             ~95,000       ~$1.90
resolveBet (win)     ~110,000      ~$2.20
resolveBet (loss)    ~80,000       ~$1.60
depositHouse         ~20,000       ~$0.40
withdrawHouse        ~25,000       ~$0.50
```

### Scalability

**Current Limitations:**

- Single contract instance
- Monolithic design
- No sharding/scaling

**Future Improvements:**

- Rollup deployment (Arbitrum, Optimism)
- Layer 2 solutions
- Multi-chain deployment

## Maintenance & Operations

### Monitoring

**Smart Contract:**

```bash
# Watch for events
cast logs --address $CONTRACT

# Monitor balance
cast call $CONTRACT "contractBalance()(uint256)"

# Check pending bets
cast call $CONTRACT "getPlayerBets(address)" $PLAYER
```

**Frontend:**

- Error logging (Sentry)
- Performance monitoring
- User analytics

### Updates

**Smart Contract:**

1. No upgradeability (immutable design)
2. New features → new contract
3. Migration path for users

**Frontend:**

1. Continuous deployment via Vercel
2. A/B testing for UI changes
3. Rollback capability

## Cost Analysis

### Deployment Cost (one-time)

```
DiceFate deployment:  ~1.5M gas (~$30 at $0.025/gas)
Initial house fund:   100 ETH (~$200,000)
Total initial cost:   ~$200,030
```

### Operating Cost (per bet)

```
User places bet:      ~95K gas (~$1.90)
House resolves:       ~100K gas (~$2.00)
Total per bet:        ~$3.90

At 1000 bets/day:     ~$3,900/day operating cost
```

### Expected Revenue

```
Assuming 1000 bets/day at 1 ETH average:
Average payout: 49% × 1.8525 = 0.907 ETH
House profit per bet: 1 - 0.907 = 0.093 ETH
Daily revenue: 1000 × 0.093 = 93 ETH
Monthly: 2,790 ETH (rough estimate)
```

## Future Enhancements

### Short Term

- [ ] Automated VRF callback (remove manual resolveBet)
- [ ] Multiple game modes (higher/lower, even/odd)
- [ ] Leaderboard system
- [ ] Referral program

### Medium Term

- [ ] Governance token (DAO)
- [ ] NFT reward system
- [ ] Multi-chain deployment
- [ ] Advanced statistics dashboard

### Long Term

- [ ] Cross-chain bridging
- [ ] Decentralized house management
- [ ] Algorithmic stablecoin payouts
- [ ] Integration with other protocols

## References

- [Solidity Best Practices](https://docs.soliditylang.org/)
- [Chainlink VRF Documentation](https://docs.chain.link/vrf)
- [Foundry Book](https://book.getfoundry.sh/)
- [wagmi Documentation](https://wagmi.sh/)
- [Next.js Documentation](https://nextjs.org/docs)

---

**Document Version:** 1.0
**Last Updated:** March 2026
**Maintained By:** DiceFate Team
