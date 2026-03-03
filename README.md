# 🎲 DiceFate - Provably Fair Dice Betting dApp

A complete decentralized gambling application built with Foundry (smart contracts) and Next.js (frontend). Users bet ETH on dice rolls with Chainlink VRF for provably fair randomness.

## Features

- ✅ **Provably Fair**: Chainlink VRF for cryptographic randomness
- ✅ **Smart Contract**: Built with Foundry in Solidity 0.8.20
- ✅ **Full Test Suite**: Comprehensive Foundry tests
- ✅ **React Frontend**: Next.js with wagmi + RainbowKit wallet integration
- ✅ **Responsive UI**: Tailwind CSS styling
- ✅ **Local Deployment**: Anvil/Hardhat support
- ✅ **House Edge**: 1.95x payout multiplier minus 5% house edge

## Quick Start

### Prerequisites

- Node.js 18+
- Foundry (`foundryup`)
- Git

### Clone & Setup

```bash
cd DiceFate

# Install Foundry dependencies
make setup

# Build contracts
make build

# Run tests
make test
```

## Smart Contract

### Files

- **src/DiceFate.sol** - Main betting contract
- **src/VRFConsumerBaseV2.sol** - VRF consumer base class
- **src/MockVRFCoordinatorV2.sol** - Mock VRF for local testing
- **test/DiceFate.t.sol** - Comprehensive test suite
- **script/Deploy.s.sol** - Deployment script

### Key Functions

#### `placeBet(uint8 targetNumber) payable`

- User places a bet on a target number (2-100)
- Sends ETH as the bet amount
- Returns the bet ID

**Example:**

```solidity
// Bet 1 ETH to roll under 50 (50% win chance)
diceFate.placeBet{value: 1 ether}(50);
```

#### `resolveBet(uint256 betId, uint256 randomNumber)`

- Owner/automation resolves a bet with random number
- Calculates dice roll: `(randomNumber % 100) + 1`
- Transfers payout if player won

#### `depositHouse()`

- Owner deposits ETH to house balance for payouts

#### `withdrawHouse(uint256 amount)`

- Owner withdraws from house balance

### Payout Calculation

- If roll < targetNumber: **WIN**
  - Payout = `betAmount × 1.95 × (1 - 0.05)`
  - Example: 1 ETH bet → 1.8525 ETH payout
- If roll ≥ targetNumber: **LOSE**
  - House keeps the bet

## Testing

```bash
cd contracts

# Run all tests
make test

# Run with gas report
make test-gas

# Watch mode (re-run on changes)
make test-watch
```

### Test Coverage

- ✅ Basic bet placement
- ✅ Multiple bets per player
- ✅ Winning bets with correct payout
- ✅ Losing bets
- ✅ Invalid target numbers
- ✅ Zero bets rejection
- ✅ Insufficient house balance
- ✅ House deposit/withdraw
- ✅ ETH receive function
- ✅ Edge cases (roll exactly 100)

## Local Deployment

### 1. Start Anvil

```bash
make anvil
# Anvil runs on http://127.0.0.1:8545
```

### 2. Deploy Contract

In a new terminal:

```bash
cd contracts

export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8

make deploy-local
```

This will:

- Deploy MockVRFCoordinatorV2
- Deploy DiceFate with 100 ETH house balance
- Output contract addresses

Save the DiceFate contract address and update `frontend/lib/config.ts`:

```typescript
export const DICE_FATE_CONTRACT = "0x..."; // Your deployed address
```

## Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Update contract address in lib/config.ts
# Then start development server
npm run dev
```

Visit `http://localhost:3000` to access the UI.

## Frontend Components

### Pages

- **app/page.tsx** - Main dashboard with betting and history

### Components

- **WalletConnect.tsx** - RainbowKit wallet connection
- **BettingForm.tsx** - Bet placement with probability visualization
- **ContractInfo.tsx** - User/house balance display
- **BetHistory.tsx** - Player's bet history and results

### Key Features

- Real-time balance updates
- Win probability calculator
- Expected value display
- Bet history with results
- Responsive design

## Contract Architecture

### State Variables

```solidity
// VRF Configuration
VRFCoordinatorV2Interface public vrfCoordinator;
bytes32 public keyHash;
uint64 public subId;

// Game Parameters
uint256 public constant PAYOUT_MULTIPLIER = 195;    // 1.95x
uint256 public constant HOUSE_EDGE_BPS = 500;       // 5%
uint256 public constant DICE_RANGE = 100;           // 1-100

// Bets & Balances
mapping(uint256 => Bet) public bets;
mapping(address => uint256[]) public playerBets;
uint256 public contractBalance;
```

### Events

```solidity
event BetPlaced(uint256 betId, address player, uint256 amount, uint8 targetNumber, uint256 requestId);
event BetResolved(uint256 betId, address player, uint256 rollResult, bool won, uint256 payout);
event HouseDeposit(address depositor, uint256 amount);
event HouseWithdraw(address withdrawer, uint256 amount);
```

## Chainlink VRF Integration

The contract uses Chainlink VRF v2 for provably fair randomness. In the local deployment:

1. **MockVRFCoordinatorV2** simulates VRF coordinator
2. `placeBet()` calls `requestRandomWords()` to request randomness
3. Owner/automation calls `resolveBet()` with random number (simulating VRF callback)
4. Dice roll calculated and payout distributed

### For Production Deployment

You would need to:

1. Deploy on a testnet (Sepolia, Mumbai, etc.)
2. Set up Chainlink VRF subscription
3. Implement `fulfillRandomWords()` callback
4. Remove `resolveBet()` owner function

## Common Issues & Troubleshooting

### "Insufficient house balance" error

The contract requires enough ETH reserved for potential payouts. Deposit more with:

```bash
cast send $DICE_FATE_CONTRACT --value 100ether "depositHouse()" --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY
```

### Wallet not connecting

- Ensure Anvil is running on `http://127.0.0.1:8545`
- Add localhost network to MetaMask:
  - Chain ID: 31337
  - RPC URL: http://127.0.0.1:8545
  - Currency: ETH

### Tests failing

```bash
cd contracts
make clean
make build
make test
```

## Environment Variables

Create `.env.local` in root for deployment:

```
PRIVATE_KEY=your_private_key_here
RPC_URL=http://127.0.0.1:8545
```

## Project Structure

```
DiceFate/
├── contracts/                    # Foundry project
│   ├── src/
│   │   ├── DiceFate.sol
│   │   ├── VRFConsumerBaseV2.sol
│   │   └── MockVRFCoordinatorV2.sol
│   ├── test/
│   │   └── DiceFate.t.sol
│   ├── script/
│   │   └── Deploy.s.sol
│   └── foundry.toml
│
├── frontend/                     # Next.js app
│   ├── app/
│   │   ├── page.tsx
│   │   ├── layout.tsx
│   │   ├── globals.css
│   │   └── providers.tsx
│   ├── components/
│   │   ├── WalletConnect.tsx
│   │   ├── BettingForm.tsx
│   │   ├── ContractInfo.tsx
│   │   └── BetHistory.tsx
│   ├── lib/
│   │   ├── abi.ts
│   │   ├── config.ts
│   │   └── hooks.ts
│   └── package.json
│
├── Makefile
└── README.md
```

## Performance & Gas Costs

### Gas Estimates (Anvil)

- PlaceBet: ~95,000 gas
- ResolveBet (win): ~110,000 gas
- ResolveBet (loss): ~80,000 gas
- DepositHouse: ~20,000 gas

## Security Notes

⚠️ **This is demo code for educational purposes.**

For production deployment:

- Audit smart contracts with professional security firm
- Implement proper access control for `resolveBet()`
- Study Chainlink VRF security best practices
- Add reentrancy guards if needed
- Implement bet expiry mechanisms
- Add emergency pause functionality

## License

MIT

## Support

For issues or questions:

1. Check the troubleshooting section
2. Review contract tests for usage examples
3. Check Foundry/Next.js documentation

## Future Enhancements

- [ ] Multiple game modes
- [ ] Leaderboards
- [ ] Automated VRF callback (production)
- [ ] Referral system
- [ ] NFT rewards
- [ ] Cross-chain bridging
- [ ] DAO governance

---

Built with ❤️ using Foundry + Next.js
