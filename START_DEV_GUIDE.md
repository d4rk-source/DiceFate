# 🚀 DiceFate Quick Start Script

## Overview

The `start-dev.sh` script **automates everything** needed to run DiceFate locally:

```bash
./start-dev.sh
```

That's it! ✨

## What It Does

1. **Checks dependencies** - Ensures Foundry, Node.js, and other tools are installed
2. **Starts Anvil** - Launches a local Ethereum blockchain (if not already running)
3. **Funds accounts** - Supplies the deployer account with 100 ETH for gas fees
4. **Builds contracts** - Compiles the smart contracts
5. **Deploys contracts** - Deploys DiceFate to the local blockchain
6. **Funds the house** - Deposits 50 ETH into the game contract
7. **Updates config** - Automatically sets the contract address in the frontend
8. **Launches frontend** - Starts the Next.js development server

**Total time: ~2 minutes**

## Prerequisites

You only need:

- **Node.js 18+** - [Download](https://nodejs.org)
- **Foundry** - [Install](https://book.getfoundry.sh/getting-started/installation)
- **Git** (usually pre-installed)

Quick Foundry install:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Usage

```bash
# From the project root
cd /path/to/DiceFate
chmod +x start-dev.sh
./start-dev.sh
```

The script will:

- Automatically detect and reuse Anvil if already running
- Show you the contract address when deployed
- Print MetaMask setup instructions
- Open the app at http://localhost:3000

## What You Get

After running the script, you'll have:

- ✅ Anvil running on `http://127.0.0.1:8545`
- ✅ DiceFate contract deployed and funded
- ✅ Frontend running at `http://localhost:3000`
- ✅ 100 ETH in your test account (ready to spend)

## MetaMask Setup (First Time Only)

When the script finishes, it prints instructions to configure MetaMask:

1. Add network "Localhost 8545" with RPC `http://127.0.0.1:8545`
2. Import the test account with private key shown in the output
3. Open http://localhost:3000 and connect your wallet

## Troubleshooting

### Script exits with dependency errors

```bash
# Install missing tools
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Anvil fails to start

```bash
# Kill any existing Anvil processes
pkill -f anvil

# Then try the script again
./start-dev.sh
```

### Frontend won't connect to contract

- Make sure MetaMask is on "Localhost 8545" network
- Refresh the page
- Check that the contract address in `frontend/lib/config.ts` matches the output

### Port already in use

If port 8545 is taken:

```bash
# Find what's using it
lsof -i :8545

# Kill the process
kill -9 <PID>
```

## Stopping Everything

```bash
# Kill Anvil
pkill -f anvil

# Stop the frontend (Ctrl+C in the terminal)
```

## Next Time

Just run:

```bash
./start-dev.sh
```

The script detects that Anvil is already running and reuses it. It will redeploy contracts each time (to a fresh state), so you start with a clean slate.

## Manual Alternative

If you prefer more control, see [GETTING_STARTED.md](GETTING_STARTED.md) for step-by-step instructions.

---

**Enjoy DiceFate! 🎲**
