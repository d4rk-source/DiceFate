# DiceFate

A home lab GameFi project I built to practise smart contract development end-to-end — from Solidity through a Foundry test suite to a React/wagmi frontend. The goal was to prove out a complete on-chain betting loop with provably fair randomness, not to build a production casino.

---

## What it does

Players pick a roll-under target (2–100) and bet ETH. A random number is drawn via Chainlink VRF; if the roll lands below the target, the player wins a payout scaled to the risk they took. The house maintains a mathematically exact 5% edge at every target level — no fixed multiplier cap, just pure math.

| Target | Win chance | Multiplier | Net payout (1 ETH bet) |
|--------|-----------|------------|------------------------|
| 2      | 1%        | ~100×      | ~95 ETH                |
| 10     | 9%        | ~11.1×     | ~10.6 ETH              |
| 50     | 49%       | ~2.04×     | ~1.94 ETH              |
| 99     | 98%       | ~1.02×     | ~0.97 ETH              |

Payout formula: `betAmount × (100 / (target − 1)) × 0.95`

---

## Stack

| Layer          | Tech                                        |
|----------------|---------------------------------------------|
| Smart contract | Solidity 0.8.20, Foundry                    |
| Randomness     | Chainlink VRF v2 (mocked locally)           |
| Frontend       | Next.js 14, wagmi v2, viem, Tailwind CSS    |
| Local chain    | Anvil (ships with Foundry)                  |

---

## Quick start

One script boots everything:

```bash
chmod +x start-dev.sh
./start-dev.sh
```

It will start Anvil, deploy the contracts, seed the house with 100 ETH, write the contract address to the frontend config, and launch `http://localhost:3000`.

**Prerequisites:** Node.js 18+, Foundry (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)

### Manual setup

```bash
# Terminal 1 — local chain
anvil

# Terminal 2 — deploy
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
make deploy-local

# Terminal 3 — frontend
cd frontend && npm install && npm run dev
```

MetaMask network: Chain ID `31337`, RPC `http://127.0.0.1:8545`. Import the private key above to get a funded test account.

---

## Contract design

```
contracts/src/
├── DiceFate.sol              — main game contract
├── VRFConsumerBaseV2.sol     — Chainlink base (vendored)
└── MockVRFCoordinatorV2.sol  — local VRF simulator
```

### Resolution paths

**Production (Chainlink VRF):**
1. `placeBet()` → `requestRandomWords()` → stores `requestId → betId`
2. Chainlink node calls `fulfillRandomWords(requestId, randomWords)` automatically
3. Contract looks up the bet via `requestIdToBetId` and settles it

**Local dev (`rollDice`):**
1. `placeBet()` → same VRF request flow (hits the mock coordinator)
2. Player clicks **Roll Dice** in the UI, which calls `rollDice(betId)` — no CLI or owner needed
3. Contract derives the roll from `block.prevrandao` mixed with bet-specific data

`rollDice` uses block entropy, which validators can weakly influence, so it is **not production-safe** — its only purpose is making the game playable locally without a Chainlink subscription. The VRF wiring (`requestRandomWords` → `fulfillRandomWords` → `requestIdToBetId` lookup) is fully implemented and tested; swapping in a real VRF subscription is the only step needed for mainnet.

Both paths share `_resolveBet()`, so the payout logic is identical regardless of how randomness arrives.

### Accounting invariant

`contractBalance` tracks available house liquidity. At any point:

```
contractBalance ≤ address(this).balance
```

When a bet is placed, `contractBalance` is reduced by the potential payout (reservation). On resolution:

- **Win** — payout sent to player; house is credited with the bet amount as partial offset.
- **Loss** — reservation is returned **and** the house is credited with the player's bet.

The invariant is verified by 128,000 calls across the Foundry invariant test suite.

### Key design choices

- **Custom errors** instead of revert strings — cheaper to decode, better DX.
- **Immutable VRF params** (`vrfCoordinator`, `keyHash`, `subId`) — set once, never changed.
- **`nextBetId` starts at 1** — zero is reserved as the "not found" sentinel in `requestIdToBetId`.
- **Checks-Effects-Interactions** throughout — all state is committed before any external ETH transfer.
- **Simple reentrancy guard** — a `_locked` bool protects `placeBet`, `resolveBet`, and `withdrawHouse`.

---

## Tests

```bash
make test          # full suite
make test-gas      # with gas report
```

The suite is organised into three contracts:

| Contract               | What it covers                                      |
|------------------------|-----------------------------------------------------|
| `DiceFateTest`         | 28 unit + integration tests                         |
| `DiceFateFuzzTest`     | 4 property-based fuzz tests (256 runs each)         |
| `DiceFateInvariantTest`| 2 invariants, 128k calls each via a stateful handler|

**Fuzz properties tested:**
- Payout is always positive
- Lower target always pays more than higher target (risk ordering)
- House edge is applied within ±1 wei of exactly 5%
- Contract balance never goes insolvent after any sequence of bets and resolutions

**VRF callback tested directly** — `test_VRFCallback_Win` and `test_VRFCallback_Loss` call `MockVRFCoordinatorV2.fulfillRandomWords()` to exercise the production `fulfillRandomWords` → `_resolveBet` path, separate from the manual `resolveBet` path.

---

## Project structure

```
DiceFate/
├── contracts/
│   ├── src/
│   │   ├── DiceFate.sol
│   │   ├── VRFConsumerBaseV2.sol
│   │   └── MockVRFCoordinatorV2.sol
│   ├── test/
│   │   └── DiceFate.t.sol        ← unit, fuzz, and invariant tests
│   ├── script/
│   │   └── Deploy.s.sol
│   └── foundry.toml
├── frontend/
│   ├── app/
│   │   ├── page.tsx
│   │   ├── layout.tsx
│   │   └── providers.tsx
│   ├── components/
│   │   ├── WalletConnect.tsx
│   │   ├── BettingForm.tsx
│   │   ├── ContractInfo.tsx
│   │   └── BetHistory.tsx
│   └── lib/
│       ├── abi.ts                ← typed ABI kept in sync with the contract
│       ├── config.ts             ← wagmi config and chain setup
│       └── hooks.ts              ← useDiceFate hook
├── Makefile
└── start-dev.sh
```

---

## Gas estimates (Anvil)

| Function           | Gas     |
|--------------------|---------|
| `placeBet`         | ~297k   |
| `resolveBet` (win) | ~361k   |
| `resolveBet` (loss)| ~350k   |
| `depositHouse`     | ~26k    |

---

## Security notes

This is demo / portfolio code. Before any real deployment:

- [ ] Professional audit
- [ ] Replace `resolveBet` with VRF-only resolution (remove the owner escape hatch)
- [ ] Set up a Chainlink VRF subscription on the target network
- [ ] Add bet expiry for requests that are never fulfilled
- [ ] Consider a `Pausable` pattern for emergency stops
- [ ] Set sensible `MIN_BET` / `MAX_BET` limits relative to house liquidity

---

## License

MIT
