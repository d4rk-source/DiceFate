# Getting Started

## Prerequisites

- **Node.js 18+** — https://nodejs.org
- **Foundry** — `curl -L https://foundry.paradigm.xyz | bash && foundryup`
- **MetaMask** (or any injected wallet) in your browser

---

## First-time setup

```bash
git clone --recurse-submodules https://github.com/d4rk-source/DiceFate
cd DiceFate
./setup.sh
```

`setup.sh` initialises the forge submodules, builds the contracts, runs the test suite, and installs the frontend npm deps. Takes about a minute.

---

## Boot the app

```bash
./start-dev.sh
```

This single script:
1. Starts Anvil on `localhost:8545`
2. Deploys the contracts and seeds the house with 100 ETH
3. Writes the contract address to the frontend config
4. Installs any missing npm deps
5. Launches the Next.js dev server at `http://localhost:3000`

---

## MetaMask setup (one-time)

**Add the local network:**
- Network name: `Localhost 8545`
- RPC URL: `http://127.0.0.1:8545`
- Chain ID: `31337`
- Currency: `ETH`

**Import a funded test account:**
```
0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```
This is Anvil's account #0 — it starts with 10,000 ETH every time Anvil runs.

---

## Playing

1. Open `http://localhost:3000` and connect your wallet.
2. Adjust the slider to pick a target (lower = riskier, higher payout).
3. Enter a bet amount and click **Place Bet**.
4. After the transaction confirms, resolve the bet from a second terminal:

```bash
export DICE_FATE_CONTRACT=<address printed by start-dev.sh>
./scripts/dice-fate-cli.sh resolve-bet 1 42
```

The second argument is an arbitrary "random" seed — the contract derives roll = `(seed % 100) + 1`. Use any number; lower seeds tend to produce lower rolls (wins more likely for high targets).

---

## CLI reference

```bash
export DICE_FATE_CONTRACT=0x...

./scripts/dice-fate-cli.sh balance                      # house liquidity
./scripts/dice-fate-cli.sh get-bet <id>                 # show bet details
./scripts/dice-fate-cli.sh resolve-bet <id> <seed>      # resolve a pending bet
./scripts/dice-fate-cli.sh place-bet <eth> <target>     # place a bet from CLI
./scripts/dice-fate-cli.sh deposit <eth>                # add house liquidity
./scripts/dice-fate-cli.sh withdraw <eth>               # remove house liquidity
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "RPC connection failed" | Make sure Anvil is running — check `/tmp/dicefate-anvil.log` |
| "Insufficient house balance" | `./scripts/dice-fate-cli.sh deposit 100` |
| Wrong network in MetaMask | Add the network above; switch to Chain ID 31337 |
| Bet pending forever | Resolve it manually with the CLI — Chainlink VRF is mocked locally |
| start-dev.sh fails on npm | Run `cd frontend && npm install` manually, then retry |

---

## Running tests

```bash
make test        # full suite (unit, fuzz, invariant)
make test-gas    # with gas report
```
