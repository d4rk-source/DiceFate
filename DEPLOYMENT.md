# DiceFate Deployment Guide

## Local Development (Anvil)

### Prerequisites

- Foundry installed (`foundryup`)
- Node.js 18+
- MetaMask or compatible Web3 wallet

### Full Setup Steps

#### 1. **Initialize Foundry Project**

```bash
cd DiceFate/contracts

# Install dependencies
forge install foundry-rs/forge-std
forge install smartcontractkit/chainlink-brownie-contracts

# Build contracts
forge build

# Run tests
forge test -v
```

#### 2. **Start Anvil Local Network**

```bash
# In Terminal 1
make anvil

# Output should show:
# Listening on 127.0.0.1:8545
# 20 Anvil accounts created
```

#### 3. **Deploy Contracts**

```bash
# In Terminal 2
cd contracts

# Set private key (or use default Anvil key)
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8

# Run deployment script
forge script script/Deploy.s.sol:Deploy \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $PRIVATE_KEY \
  -vvv \
  --broadcast
```

**Example Output:**

```
==============
Deployment Simulation
==============
...
MockVRFCoordinatorV2 deployed at: 0x5FbDB2315678afccb333f8a9c45b65d30424b7B1h
DiceFate deployed at: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
House deposited with: 100 ETH
```

#### 4. **Save Contract Address**

Update `frontend/lib/config.ts`:

```typescript
export const DICE_FATE_CONTRACT = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
```

Or create `.env.local`:

```
NEXT_PUBLIC_DICE_FATE_CONTRACT=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

#### 5. **Setup MetaMask for Localhost**

1. Open MetaMask
2. Click network dropdown → Add a custom network
3. Fill in:
   - Network name: `Localhost 8545`
   - RPC URL: `http://127.0.0.1:8545`
   - Chain ID: `31337`
   - Currency: `ETH`
4. Save

#### 6. **Import Anvil Account to MetaMask**

1. Click account icon → Import Account
2. Paste private key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8`
3. Import

Account should show 10,000 ETH balance.

#### 7. **Start Frontend**

```bash
# In Terminal 3
cd frontend
npm install
npm run dev

# Visit http://localhost:3000
```

#### 8. **Connect Wallet & Place Bet**

1. Click "Connect Wallet" on frontend
2. Select MetaMask
3. Approve connection
4. Set bet parameters:
   - Target: 50 (50% win probability)
   - Amount: 0.1 ETH
5. Click "Place Bet"
6. Approve transaction in MetaMask

#### 9. **Resolve Bet (Simulate VRF)**

Since we're using MockVRFCoordinator, you manually resolve bets:

```bash
# In Terminal 2
export DICE_FATE_CONTRACT=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8

# Resolve bet #1 with random number 25 (win!)
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

## Testnet Deployment (Sepolia Example)

### Prerequisites

- Testnet ETH for gas
- Chainlink VRF subscription (https://vrf.chain.link)

### Steps

#### 1. **Get Testnet RPC**

```bash
# Alchemy, Infura, or public RPC
export RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
```

#### 2. **Set Network Configuration**

```bash
cd contracts

# Create .env
cat > .env << EOF
PRIVATE_KEY=your_private_key_here
RPC_URL=$RPC_URL
ETHERSCAN_API_KEY=your_etherscan_key
EOF

source .env
```

#### 3. **Deploy to Testnet**

```bash
# Update keyHash and subId for Sepolia
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  -vvv \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

#### 4. **Configure Frontend**

```bash
# frontend/.env.local
NEXT_PUBLIC_DICE_FATE_CONTRACT=0x...
NEXT_PUBLIC_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/...
```

## Production Deployment (Mainnet)

⚠️ **Security Audit Required Before Mainnet!**

### Checklist

- [ ] Smart contract audited by professional firm
- [ ] All tests passing with >95% coverage
- [ ] Access control properly implemented
- [ ] VRF subscription funded and configured
- [ ] Emergency pause/withdraw functions added
- [ ] Bug bounty program established
- [ ] Insurance/protocol fund established

### Deployment Steps

```bash
# Similar to testnet, but on mainnet RPC
export RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY

forge script script/Deploy.s.sol:Deploy \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  -vvv \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## Contract Interaction Examples

### Via Foundry (cast)

```bash
# Get contract balance
cast call $DICE_FATE_CONTRACT "contractBalance()(uint256)" $RPC_ARGS

# Get player's bets
cast call $DICE_FATE_CONTRACT \
  "getPlayerBets(address)(uint256[])" \
  0xYourAddress \
  $RPC_ARGS

# Get specific bet details
cast call $DICE_FATE_CONTRACT \
  "getBet(uint256)(address,uint256,uint8,uint256,bool,bool)" \
  1 \
  $RPC_ARGS

# Place a bet (1 ETH, target 50)
cast send $DICE_FATE_CONTRACT \
  "placeBet(uint8)" \
  50 \
  --value 1ether \
  $RPC_ARGS

# Resolve bet (owner only)
cast send $DICE_FATE_CONTRACT \
  "resolveBet(uint256,uint256)" \
  1 \
  42 \
  $RPC_ARGS

# Deposit to house
cast send $DICE_FATE_CONTRACT \
  "depositHouse()" \
  --value 100ether \
  $RPC_ARGS
```

### Via ethers.js / Frontend

See `frontend/lib/hooks.ts` for React hook examples.

## Troubleshooting Deployment

### "Failed to connect to RPC"

```bash
# Verify endpoint is accessible
curl $RPC_URL -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### "Transaction reverted: insufficient balance"

```bash
# Check account balance
cast balance $YOUR_ADDRESS --rpc-url $RPC_URL
```

### "Contract deployment failed"

```bash
# Get more details
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $RPC_URL \
  -vvvv  # Extra verbosity
```

### "Verification failed"

```bash
# Verify manually after deployment
forge verify-contract $CONTRACT_ADDRESS \
  src/DiceFate.sol:DiceFate \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --compiler-version v0.8.20
```

## Monitoring Deployed Contracts

### Anvil Local

```bash
# Watch transaction pool
cast rpc eth_getTransactionByHash $TX_HASH

# Watch events
cast logs --address $DICE_FATE_CONTRACT
```

### Testnet/Mainnet

- Use Etherscan block explorer
- Set up The Graph for advanced queries
- Use Alchemy dashboard for RPC monitoring

## Updating Contract Code

### Local Development

```bash
# Make changes to src/DiceFate.sol
# Test
forge test

# Redeploy
forge script script/Deploy.s.sol:Deploy --broadcast
```

### Production Gradual Rollout

1. Deploy to local testnet
2. Test thoroughly (1+ weeks)
3. Deploy to public testnet
4. Get community feedback
5. Deploy to mainnet with monitoring

## Gas Optimization

```bash
# See gas usage
forge test --gas-report

# Benchmark across versions
forge test --gas-report > baseline.txt
# Make changes...
forge test --gas-report > optimized.txt
```

## Common Deployment Issues

### Nonce Issues

```bash
# Reset anvil state
killall anvil
make anvil

# Or manually manage nonce
export FOUNDRY_ETH_FROM=0xYourAddress
cast nonce $YOUR_ADDRESS
```

### Insufficient House Balance

```bash
# Deposit more ETH
cast send $DICE_FATE_CONTRACT "depositHouse()" --value 500ether $RPC_ARGS
```

### Bet Doesn't Resolve

Check:

- Bet ID is correct
- Random number is 0-99 (gets converted to 1-100)
- Owner account is used for resolveBet

---

Need help? Check [README.md](README.md) for more details!
