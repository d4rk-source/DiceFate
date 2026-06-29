#!/bin/bash
# CLI helper for interacting with a deployed DiceFate contract.
# Reads DICE_FATE_CONTRACT and optionally PRIVATE_KEY and RPC_URL from the env.
#
# Usage:
#   export DICE_FATE_CONTRACT=0x...
#   ./scripts/dice-fate-cli.sh <command> [args...]
#
# Commands:
#   balance                           Print house liquidity
#   place-bet <amount_eth> <target>   Place a bet (requires PRIVATE_KEY)
#   get-bet <id>                      Show bet details
#   resolve-bet <id> <random>         Resolve a bet — owner only (requires PRIVATE_KEY)
#   deposit <amount_eth>              Add house liquidity — owner only (requires PRIVATE_KEY)
#   withdraw <amount_eth>             Remove house liquidity — owner only (requires PRIVATE_KEY)

set -euo pipefail

PK="${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
RPC="${RPC_URL:-http://127.0.0.1:8545}"
ADDR="${DICE_FATE_CONTRACT:-}"

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $*"; }
info() { echo -e "${BLUE}→${NC} $*"; }
die()  { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }

# ── Guard ──────────────────────────────────────────────────────────────────────
[ -z "$ADDR" ] && die "DICE_FATE_CONTRACT is not set. Export it first:
  export DICE_FATE_CONTRACT=0x..."

CMD="${1:-}"
[ -z "$CMD" ] && {
    grep '^#   [a-z]' "$0" | sed 's/^#   /  /'
    exit 0
}

# ── Commands ───────────────────────────────────────────────────────────────────
case "$CMD" in
    balance)
        info "House liquidity:"
        RAW=$(cast call "$ADDR" "contractBalance()(uint256)" --rpc-url "$RPC")
        cast to-unit "$RAW" ether
        ;;

    place-bet)
        AMOUNT="${2:-}"; TARGET="${3:-}"
        [ -z "$AMOUNT" ] || [ -z "$TARGET" ] && die "Usage: place-bet <amount_eth> <target>"
        info "Placing bet: ${AMOUNT} ETH, roll under ${TARGET} ..."
        cast send "$ADDR" "placeBet(uint8)" "$TARGET" \
            --value "${AMOUNT}ether" --rpc-url "$RPC" --private-key "$PK"
        ok "Bet placed"
        ;;

    get-bet)
        BET_ID="${2:-}"
        [ -z "$BET_ID" ] && die "Usage: get-bet <id>"
        info "Bet #${BET_ID}:"
        # Struct: player, amount, targetNumber, requestId, rollResult, resolved, won
        cast call "$ADDR" \
            "getBet(uint256)(address,uint256,uint8,uint256,uint256,bool,bool)" \
            "$BET_ID" --rpc-url "$RPC"
        ;;

    resolve-bet)
        BET_ID="${2:-}"; RAND="${3:-}"
        [ -z "$BET_ID" ] || [ -z "$RAND" ] && die "Usage: resolve-bet <id> <random_number>"
        info "Resolving bet #${BET_ID} with seed ${RAND} ..."
        cast send "$ADDR" "resolveBet(uint256,uint256)" "$BET_ID" "$RAND" \
            --rpc-url "$RPC" --private-key "$PK"
        ok "Bet resolved"
        ;;

    deposit)
        AMOUNT="${2:-}"
        [ -z "$AMOUNT" ] && die "Usage: deposit <amount_eth>"
        info "Depositing ${AMOUNT} ETH to house ..."
        cast send "$ADDR" "depositHouse()" \
            --value "${AMOUNT}ether" --rpc-url "$RPC" --private-key "$PK"
        ok "Deposited"
        ;;

    withdraw)
        AMOUNT="${2:-}"
        [ -z "$AMOUNT" ] && die "Usage: withdraw <amount_eth>"
        info "Withdrawing ${AMOUNT} ETH from house ..."
        AMOUNT_WEI=$(cast to-unit "$AMOUNT" wei 2>/dev/null || cast to-wei "$AMOUNT" ether)
        cast send "$ADDR" "withdrawHouse(uint256)" "$AMOUNT_WEI" \
            --rpc-url "$RPC" --private-key "$PK"
        ok "Withdrawn"
        ;;

    *)
        die "Unknown command: $CMD"
        ;;
esac
