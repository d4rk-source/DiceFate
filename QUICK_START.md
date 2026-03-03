# Quick Start Guide - DiceFate

## 5-Minute Setup

### Step 1: Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Step 2: Clone & Install

```bash
cd DiceFate/contracts
make setup
```

### Step 3: Run Tests

```bash
make test
```

### Step 4: Start Anvil in Terminal 1

```bash
make anvil
```

### Step 5: Deploy in Terminal 2

```bash
cd contracts
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8
make deploy-local
```

Take note of the DiceFate contract address from the output.

### Step 6: Update Frontend Config

Edit `frontend/lib/config.ts`:

```typescript
export const DICE_FATE_CONTRACT = "0x..."; // Your address here
```

### Step 7: Start Frontend in Terminal 3

```bash
cd frontend
npm install
npm run dev
```

### Step 8: Connect Wallet

1. Open http://localhost:3000
2. Add localhost to MetaMask:
   - Network Name: Localhost
   - RPC: http://127.0.0.1:8545
   - Chain ID: 31337
3. Use default Anvil account: `0xf39Fd6e51aad88f6f4ce6aB8827279cffFb92266`

### Step 9: Place a Bet!

- Select a target number (50 = 50% win chance)
- Set bet amount (0.1 ETH)
- Click "Place Bet"
- In another terminal, simulate VRF resolution:

```bash
cast send $DICE_FATE_CONTRACT \
  "resolveBet(uint256,uint256)" \
  1 42 \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8
```

Replace `1` with bet ID and `42` with random number (0-99).

## Useful Commands

### Check Contract State

```bash
# Get house balance
cast call $DICE_FATE_CONTRACT "contractBalance()(uint256)" --rpc-url http://localhost:8545

# Get specific bet
cast call $DICE_FATE_CONTRACT "getBet(uint256)(tuple)" 1 --rpc-url http://localhost:8545
```

### Deposit More ETH to House

```bash
cast send $DICE_FATE_CONTRACT \
  "depositHouse()" \
  --value 100ether \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY
```

### Execute Tests with Coverage

```bash
cd contracts
forge coverage
```

## Troubleshooting

**Q: "RPC URL error"**

- Ensure Anvil is running: `make anvil`
- Check it's on http://127.0.0.1:8545

**Q: "Insufficient house balance"**

- Deploy again or deposit more
- See "Deposit More ETH" command above

**Q: Frontend won't connect to wallet**

- Check MetaMask is on Localhost (Chain ID 31337)
- Refresh page after adding network

**Q: Tests failing**

```bash
cd contracts
forge clean
forge build
forge test -vvv
```

## Next Steps

1. ✅ Explore contract functions in `src/DiceFate.sol`
2. ✅ Review test cases in `test/DiceFate.t.sol`
3. ✅ Modify game parameters (payout ratio, house edge)
4. ✅ Add more game modes
5. ✅ Deploy to testnet

## Environment Setup Guide

### For VS Code

Install extensions:

1. Solidity (Juan Blanco)
2. Foundry for Solidity
3. ES7+ React/Redux snippets

### Anvil Accounts

Default Anvil seed generates these accounts with 10,000 ETH each:

```
Account 0: 0xf39Fd6e51aad88f6f4ce6aB8827279cffFb92266
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8

Account 1: 0x70997970C51812e339D9B73b0245ad59419F56BE
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

... (20 total accounts)
```

Use different accounts in MetaMask for testing multiple players!

## Performance Tips

- Use `make test-gas` to optimize contract
- Monitor contract balance with `cast call`
- Use Anvil's fast mode for rapid tests
- Clear cache regularly: `make clean`

---

Happy betting! 🎲
