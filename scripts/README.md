# 🎲 DiceFate Scripts

Quick reference for all available scripts.

## Quick Start (Recommended)

```bash
./start-dev.sh
```

Automatically starts Anvil, deploys contracts, configures the frontend, and launches the app. **One command, everything works.**

See [START_DEV_GUIDE.md](../START_DEV_GUIDE.md) for details.

---

## Individual Scripts

### `setup.sh` - Initial Setup

Installs dependencies and builds the project (no deployment).

```bash
cd /path/to/DiceFate
chmod +x setup.sh
./setup.sh
```

**Does:**

- Installs Foundry dependencies
- Builds smart contracts
- Runs automated tests
- Installs frontend dependencies

### `start-dev.sh` - Automated Full Startup

Handles everything: Anvil, deployment, configuration, and frontend launch.

```bash
chmod +x start-dev.sh
./start-dev.sh
```

**Does:**

- Starts Anvil (local blockchain)
- Funds the deployer account with 100 ETH
- Builds contracts
- Deploys DiceFate
- Funds the game house with 50 ETH
- Updates frontend config
- Launches frontend at http://localhost:3000

### `dice-fate-cli.sh` - Contract Interactions

Helper script for manual contract interactions via the CLI.

```bash
export DICE_FATE_CONTRACT=0x724f801f87f4f760091c2efd0805a8f5ea0974f9
./scripts/dice-fate-cli.sh <command> [args...]
```

**Commands:**

```bash
# Check contract balance
./scripts/dice-fate-cli.sh balance

# Place a bet (0.1 ETH, target under 50)
./scripts/dice-fate-cli.sh place-bet 0.1 50

# Get bet details
./scripts/dice-fate-cli.sh get-bet 1

# Resolve a bet (owner only, bet ID 1, roll 25)
./scripts/dice-fate-cli.sh resolve-bet 1 25

# Deposit to house (owner only)
./scripts/dice-fate-cli.sh deposit 10

# Withdraw from house (owner only)
./scripts/dice-fate-cli.sh withdraw 5
```

### `e2e-test.sh` - End-to-End Testing

Runs a complete game simulation (requires running Anvil first).

```bash
# In Terminal 1
make anvil

# In Terminal 2
./scripts/e2e-test.sh
```

**Tests:**

- Deploys contracts
- Places bets
- Resolves bets
- Verifies payouts

---

## Makefile Commands

The project also includes convenient `make` commands:

```bash
# Start local blockchain
make anvil

# Build contracts
make build

# Run contract tests
make test

# Run tests with gas reports
make test-gas

# Deploy to localhost (manual, requires setup)
make deploy-local

# Clean build artifacts
make clean

# Install frontend dependencies
make frontend-install

# Start frontend dev server
make frontend-dev

# Build frontend for production
make frontend-build
```

---

## Typical Workflow

After initial setup:

```bash
# Day 1: Full automated setup
./start-dev.sh

# Subsequent days: Just run again (reuses running Anvil)
./start-dev.sh

# Or use individual commands:
make anvil              # Terminal 1
make deploy-local       # Terminal 2
make frontend-dev       # Terminal 3
```

---

## Environment Variables

The scripts use these environment variables:

```bash
# Private key for deployment (default: first Anvil account)
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8

# RPC URL (default: http://127.0.0.1:8545)
export RPC_URL=http://127.0.0.1:8545

# Deployed contract address
export DICE_FATE_CONTRACT=0x724f801f87f4f760091c2efd0805a8f5ea0974f9
```

---

## Troubleshooting

### Script Permission Denied

```bash
chmod +x <script-name>
```

### Anvil Not Starting

```bash
# Kill any existing Anvil processes
pkill -f anvil

# Try again
./start-dev.sh
```

### Contract Address Not Found

Make sure deployment completed successfully:

```bash
cast block-number --rpc-url http://127.0.0.1:8545
```

Should return a number if Anvil is running and contracts are deployed.

---

**Need help?** See [GETTING_STARTED.md](../GETTING_STARTED.md) or [START_DEV_GUIDE.md](../START_DEV_GUIDE.md)
