# 🎲 DiceFate - Getting Started

## Welcome! 👋

This is a complete decentralized gambling dApp. Let's get you up and running in minutes.

## What is DiceFate?

A smart contract-based dice betting game where you:

1. **Bet ETH** on a dice roll (1-100)
2. **Win if** the dice rolls under your target number
3. **Get paid** 1.95x your bet minus 5% if you win
4. **Verify fairness** with Chainlink VRF randomness

## System Requirements

- **Node.js** 18+ ([Download](https://nodejs.org))
- **Foundry** ([Install](https://book.getfoundry.sh/getting-started/installation))
- **Git** (usually pre-installed)
- **MetaMask** browser extension (for frontend)

## Installation (Choose One)

### Option A: Automatic Setup (Recommended)

```bash
cd /home/d4rk/my_folder/my_github/DiceFate
chmod +x setup.sh
./setup.sh
```

This script will:

- Install Foundry dependencies
- Build smart contracts
- Run automated tests
- Install frontend dependencies

**Time: ~5-10 minutes**

### Option B: Manual Setup

```bash
# Navigate to project
cd /home/d4rk/my_folder/my_github/DiceFate

# Setup Foundry
cd contracts
forge install foundry-rs/forge-std
forge install smartcontractkit/chainlink-brownie-contracts
forge build
forge test

# Setup Frontend
cd ../frontend
npm install
```

**Time: ~10-15 minutes**

## Running the dApp

### Step 1: Start Local Blockchain

**Terminal 1:**

```bash
cd /home/d4rk/my_folder/my_github/DiceFate
make anvil
```

You should see:

```
Listening on 127.0.0.1:8545
Anvil is running the following accounts:
0xf39Fd6e51aad88f6f4ce6aB8827279cffFb92266
...
```

Leave this running.

### Step 2: Deploy Smart Contract

**Terminal 2:**

```bash
cd /home/d4rk/my_folder/my_github/DiceFate/contracts

export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8

make deploy-local
```

You'll see output like:

```
DiceFate deployed at: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

**Save this address!** You'll need it next.

### Step 3: Configure Frontend

Edit `frontend/lib/config.ts`:

Find this line:

```typescript
export const DICE_FATE_CONTRACT = "0x1234567890123456789012345678901234567890";
```

Replace with your contract address:

```typescript
export const DICE_FATE_CONTRACT = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
```

Save the file.

### Step 4: Start Frontend

**Terminal 3:**

```bash
cd /home/d4rk/my_folder/my_github/DiceFate/frontend
npm run dev
```

You should see:

```
Ready in 2.1s
▲ Next.js 14.0.0
  - Local:        http://localhost:3000
```

### Step 5: Configure MetaMask (First Time Only)

1. Open MetaMask
2. Click the network dropdown
3. Add a custom network:
   - **Name:** Localhost 8545
   - **RPC URL:** http://127.0.0.1:8545
   - **Chain ID:** 31337
   - **Currency:** ETH

4. Switch to this network

### Step 6: Import Anvil Account

1. Click account icon in MetaMask
2. Click "Import Account"
3. Paste private key:
   ```
   0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8
   ```
4. Click Import

You should now see **10,000 ETH** in your account!

### Step 7: Visit the App

1. Open http://localhost:3000
2. Click "Connect Wallet"
3. Select MetaMask
4. Approve connection

**You're in!** 🎉

## Place Your First Bet

1. **Set Target Number:** Use slider (default 50 = 50% win chance)
2. **Set Bet Amount:** Enter 0.1 (ETH)
3. **Click "Place Bet"**
4. **Approve** in MetaMask
5. **Wait** for transaction (instant on Anvil)

## Resolve Your Bet (Simulate VRF)

Since we're using a mock VRF locally, you need to manually "roll the dice":

**In Terminal 2:**

```bash
# Resolve bet #1 with random number 25
# (25 < 50 = WIN!)
export DICE_FATE_CONTRACT=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8

cast send $DICE_FATE_CONTRACT \
  "resolveBet(uint256,uint256)" \
  1 \
  25 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY
```

Or use the CLI helper:

```bash
./scripts/dice-fate-cli.sh resolve-bet 1 25
```

## View Your Results

1. Go to **Bet History** section on the frontend
2. You should see your bet with status "Won ✓" or "Lost ✗"
3. If you won, your balance increased! 💰

## Test Losing Scenario

```bash
export DICE_FATE_CONTRACT=0x...
export PRIVATE_KEY=0xac0974...

# Place another bet
cast send $DICE_FATE_CONTRACT \
  "placeBet(uint8)" \
  50 \
  --value 1ether \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY

# Resolve with number >= 50 (LOSE)
cast send $DICE_FATE_CONTRACT \
  "resolveBet(uint256,uint256)" \
  2 \
  75 \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY
```

## Useful Commands

```bash
# Check contract balance
cast call $DICE_FATE_CONTRACT "contractBalance()(uint256)" --rpc-url http://localhost:8545

# Check your bets
cast call $DICE_FATE_CONTRACT "getPlayerBets(address)(uint256[])" 0xf39Fd6e51aad88f6f4ce6aB8827279cffFb92266 --rpc-url http://localhost:8545

# Deposit more ETH to house
cast send $DICE_FATE_CONTRACT "depositHouse()" --value 100ether --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY

# Run tests
cd contracts && forge test -v
```

## Troubleshooting

### "RPC connection failed"

- Make sure Anvil is running in Terminal 1
- Check it says "Listening on 127.0.0.1:8545"

### "Insufficient house balance"

- The contract doesn't have enough funds for your bet size
- Deposit more: `cast send $DICE_FATE_CONTRACT "depositHouse()" --value 500ether`

### MetaMask won't connect

- Make sure MetaMask is set to "Localhost 8545"
- Try refreshing the page
- Make sure account is imported with 10,000 ETH

### Contract address not set

- Edit `frontend/lib/config.ts`
- Get address from Step 2 deployment output
- Make sure it starts with "0x"

### Tests are failing

```bash
cd contracts
forge clean
forge build
forge test -vvv
```

## Next Steps

1. ✅ **Understand the Game:** Read [README.md](README.md)
2. ✅ **Explore the Code:** Check `contracts/src/DiceFate.sol`
3. ✅ **Read Tests:** Look at `contracts/test/DiceFate.t.sol`
4. ✅ **Learn Architecture:** Read [ARCHITECTURE.md](ARCHITECTURE.md)
5. ✅ **Deploy to Testnet:** Follow [DEPLOYMENT.md](DEPLOYMENT.md)

## Project Structure

```
DiceFate/
├── contracts/          # Smart contracts (Foundry)
│   ├── src/           # Contract code
│   ├── test/          # Automated tests
│   └── script/        # Deployment scripts
│
├── frontend/          # React dApp
│   ├── app/           # Next.js pages
│   ├── components/    # React components
│   └── lib/           # Utilities & hooks
│
├── docs/             # Documentation
│   ├── README.md     # Overview
│   ├── QUICK_START.md    # This file
│   ├── DEPLOYMENT.md     # Deployment guide
│   └── ARCHITECTURE.md   # Technical details
│
└── scripts/          # Utility scripts
    ├── setup.sh      # Auto setup
    ├── dice-fate-cli.sh   # CLI tool
    └── e2e-test.sh   # End-to-end test
```

## Game Rules Reminder

| Rule          | Value                                                   |
| ------------- | ------------------------------------------------------- |
| Dice Range    | 1-100                                                   |
| Win Condition | Roll < Target                                           |
| Payout if Win | 1.95x × (1 - 5%) = **1.8525x your bet**                 |
| House Edge    | 5%                                                      |
| Example       | Bet 1 ETH on <50: 49% win chance, if win get 1.8525 ETH |

## Common Commands Cheat Sheet

```bash
# Start fresh
killall anvil
make anvil

# Deploy
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8
make deploy-local

# Place bet (1 ETH, target 50)
cast send $DICE_FATE_CONTRACT "placeBet(uint8)" 50 \
  --value 1ether --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY

# Resolve bet (win)
cast send $DICE_FATE_CONTRACT "resolveBet(uint256,uint256)" 1 25 \
  --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Frontend
cd frontend && npm run dev
```

## Ready? 🚀

1. Open 3 terminals
2. Run the commands above
3. Visit http://localhost:3000
4. Start betting!

## Questions?

- 📖 Read [README.md](README.md) for features
- 🏗️ Check [ARCHITECTURE.md](ARCHITECTURE.md) for design
- 🚀 See [DEPLOYMENT.md](DEPLOYMENT.md) for testnet setup
- 💡 Review contract code: `contracts/src/DiceFate.sol`
- 🧪 Run tests: `cd contracts && forge test -v`

---

**Have fun and good luck! 🎲**

_Remember: This is a demo. Only use with Anvil locally for now._
