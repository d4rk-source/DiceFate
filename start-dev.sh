#!/bin/bash
# DiceFate local dev launcher
# Starts Anvil, deploys contracts, seeds the house, then launches the frontend.
# Usage: ./start-dev.sh

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
RPC="http://127.0.0.1:8545"
# Anvil account #0 — pre-funded with 10,000 ETH on every Anvil startup.
PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
HOUSE_ETH=100
# Optional: set PLAYER_ADDR to airdrop test ETH to your own wallet.
PLAYER_ADDR="${PLAYER_ADDR:-}"
PLAYER_ETH="${PLAYER_ETH:-10}"

# ── Helpers ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC}  $*"; }
info() { echo -e "  ${BLUE}→${NC}  $*"; }
die()  { echo -e "\n  ${RED}✗  $*${NC}\n" >&2; exit 1; }

# Run a command, show its output only if it fails.
run_silent() {
    local label="$1"; shift
    info "$label ..."
    local out
    out=$("$@" 2>&1) && ok "$label" || { echo "$out" >&2; die "$label failed"; }
}

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${BLUE}DiceFate${NC} — local dev startup"
echo ""

# ── Dependency check ─────────────────────────────────────────────────────────
for cmd in anvil forge cast node npm; do
    command -v "$cmd" >/dev/null 2>&1 \
        || die "'$cmd' not found. See README for install instructions."
done
ok "dependencies OK (anvil, forge, cast, node, npm)"

# ── Anvil ─────────────────────────────────────────────────────────────────────
if cast block-number --rpc-url "$RPC" >/dev/null 2>&1; then
    ok "Anvil already running on $RPC"
else
    info "Starting Anvil on $RPC ..."
    anvil --host 127.0.0.1 --port 8545 >/tmp/dicefate-anvil.log 2>&1 &
    ANVIL_PID=$!
    for i in $(seq 1 30); do
        cast block-number --rpc-url "$RPC" >/dev/null 2>&1 && break
        [ "$i" -eq 30 ] && die "Anvil failed to start — check /tmp/dicefate-anvil.log"
        sleep 1
    done
    ok "Anvil started (PID $ANVIL_PID)"
fi

# ── Contracts ─────────────────────────────────────────────────────────────────
cd contracts

run_silent "Building contracts" forge build

info "Deploying contracts ..."
DEPLOY_OUT=$(PRIVATE_KEY="$PK" forge script script/Deploy.s.sol:Deploy \
    --rpc-url "$RPC" --private-key "$PK" --broadcast 2>&1) \
    || { echo "$DEPLOY_OUT" >&2; die "Deployment failed"; }
ok "Contracts deployed"

# Parse the DiceFate address out of the broadcast artefact.
ADDR=$(grep -A 1 '"contractName": "DiceFate"' broadcast/Deploy.s.sol/31337/run-latest.json \
       | grep -o '0x[a-fA-F0-9]*' | head -1)
[ -z "$ADDR" ] && die "Could not parse DiceFate address from broadcast output."
echo -e "       address: ${BLUE}${ADDR}${NC}"

info "Funding house with ${HOUSE_ETH} ETH ..."
cast send "$ADDR" "depositHouse()" \
    --value "${HOUSE_ETH}ether" --rpc-url "$RPC" --private-key "$PK" \
    >/dev/null 2>&1 \
    && ok "House funded with ${HOUSE_ETH} ETH" \
    || { echo -e "  ${YELLOW}!${NC}  House deposit failed — fund manually after startup."; }

if [ -n "$PLAYER_ADDR" ]; then
    info "Airdropping ${PLAYER_ETH} ETH to ${PLAYER_ADDR} ..."
    cast send "$PLAYER_ADDR" \
        --value "${PLAYER_ETH}ether" --rpc-url "$RPC" --private-key "$PK" \
        >/dev/null 2>&1 \
        && ok "Airdropped ${PLAYER_ETH} ETH to ${PLAYER_ADDR}" \
        || echo -e "  ${YELLOW}!${NC}  Airdrop failed — fund manually: cast send $PLAYER_ADDR --value ${PLAYER_ETH}ether --private-key \$PK"
fi

cd ..

# ── Frontend ──────────────────────────────────────────────────────────────────
cd frontend

run_silent "Installing frontend dependencies" npm install --silent

info "Writing contract address to frontend config ..."
sed -i.bak "s|export const DICE_FATE_CONTRACT = .*|export const DICE_FATE_CONTRACT = \"${ADDR}\";|" \
    lib/config.ts
rm -f lib/config.ts.bak
ok "Config updated"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}All set!${NC}"
echo ""
echo -e "  Contract : ${BLUE}${ADDR}${NC}"
echo -e "  RPC      : ${BLUE}${RPC}${NC}"
echo -e "  App      : ${BLUE}http://localhost:3000${NC} (starting now)"
echo ""
echo -e "  ${YELLOW}MetaMask (one-time setup):${NC}"
echo -e "    Network → Add network → Chain ID 31337, RPC ${RPC}"
echo -e "    Import account with key: ${PK}  (10,000 ETH)"
echo -e "    Or fund your own address:  PLAYER_ADDR=0x... ./start-dev.sh"
echo ""
echo -e "  ${YELLOW}To resolve a bet (simulates VRF):${NC}"
echo -e "    export DICE_FATE_CONTRACT=${ADDR}"
echo -e "    ./scripts/dice-fate-cli.sh resolve-bet <betId> <randomNumber>"
echo ""

npm run dev
