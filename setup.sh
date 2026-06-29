#!/bin/bash
# DiceFate one-time dependency installer.
# Run this once after cloning. Then use ./start-dev.sh to boot the app.

set -euo pipefail

GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
ok()  { echo -e "  ${GREEN}✓${NC}  $*"; }
info(){ echo -e "  ${BLUE}→${NC}  $*"; }
die() { echo -e "\n  ${RED}✗  $*${NC}\n" >&2; exit 1; }

echo ""
echo -e "  ${BLUE}DiceFate${NC} — one-time setup"
echo ""

# ── Dependency check ──────────────────────────────────────────────────────────
for cmd in forge node npm git; do
    command -v "$cmd" >/dev/null 2>&1 \
        || die "'$cmd' not found. See README for install instructions."
done
ok "dependencies OK (forge, node, npm, git)"

# ── Forge libraries ───────────────────────────────────────────────────────────
info "Initialising git submodules (forge-std, chainlink-brownie-contracts) ..."
git submodule update --init --recursive
ok "Submodules initialised"

# If submodules came up empty for some reason, install via forge.
if [ ! -f "contracts/lib/forge-std/src/Test.sol" ]; then
    info "forge-std not found via submodule — installing via forge ..."
    cd contracts && forge install foundry-rs/forge-std --no-commit && cd ..
fi

# ── Build + test ──────────────────────────────────────────────────────────────
info "Building contracts ..."
cd contracts
forge build
ok "Contracts built"

info "Running test suite ..."
forge test
ok "All tests passed"
cd ..

# ── Frontend ──────────────────────────────────────────────────────────────────
info "Installing frontend dependencies ..."
cd frontend && npm install && cd ..
ok "Frontend dependencies installed"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}Setup complete.${NC}"
echo ""
echo -e "  Run ${BLUE}./start-dev.sh${NC} to boot Anvil, deploy, and launch the app."
echo ""
