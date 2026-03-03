#!/bin/bash
# Helper script for contract interactions

PRIVATE_KEY=${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8}
RPC_URL=${RPC_URL:-http://127.0.0.1:8545}

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get contract address from argument or environment
CONTRACT_ADDRESS=${1:-$DICE_FATE_CONTRACT}

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo -e "${YELLOW}Usage:${NC}"
    echo "  ./scripts/dice-fate-cli.sh <command> [args...]"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo "  balance                     Get contract balance"
    echo "  place-bet <amount> <target> Place a bet (amount in ETH)"
    echo "  get-bet <id>                Get bet details"
    echo "  resolve-bet <id> <random>   Resolve a bet (owner only)"
    echo "  deposit <amount>            Deposit to house (amount in ETH, owner only)"
    echo "  withdraw <amount>           Withdraw from house (amount in ETH, owner only)"
    exit 0
fi

COMMAND=$1
DICE_FATE_CONTRACT=$CONTRACT_ADDRESS

case $COMMAND in
    balance)
        echo -e "${BLUE}Getting contract balance...${NC}"
        cast call $DICE_FATE_CONTRACT "contractBalance()(uint256)" --rpc-url $RPC_URL
        ;;
    place-bet)
        AMOUNT=$2
        TARGET=$3
        if [ -z "$AMOUNT" ] || [ -z "$TARGET" ]; then
            echo -e "${YELLOW}Usage: ./scripts/dice-fate-cli.sh place-bet <amount_eth> <target>${NC}"
            exit 1
        fi
        echo -e "${BLUE}Placing bet: ${AMOUNT} ETH, target under ${TARGET}...${NC}"
        cast send $DICE_FATE_CONTRACT \
            "placeBet(uint8)" \
            $TARGET \
            --value ${AMOUNT}ether \
            --rpc-url $RPC_URL \
            --private-key $PRIVATE_KEY
        ;;
    get-bet)
        BET_ID=$2
        if [ -z "$BET_ID" ]; then
            echo -e "${YELLOW}Usage: ./scripts/dice-fate-cli.sh get-bet <id>${NC}"
            exit 1
        fi
        echo -e "${BLUE}Getting bet #${BET_ID}...${NC}"
        cast call $DICE_FATE_CONTRACT "getBet(uint256)(address,uint256,uint8,uint256,bool,bool)" $BET_ID --rpc-url $RPC_URL
        ;;
    resolve-bet)
        BET_ID=$2
        RANDOM=$3
        if [ -z "$BET_ID" ] || [ -z "$RANDOM" ]; then
            echo -e "${YELLOW}Usage: ./scripts/dice-fate-cli.sh resolve-bet <id> <random_number>${NC}"
            exit 1
        fi
        echo -e "${BLUE}Resolving bet #${BET_ID} with random ${RANDOM}...${NC}"
        cast send $DICE_FATE_CONTRACT \
            "resolveBet(uint256,uint256)" \
            $BET_ID \
            $RANDOM \
            --rpc-url $RPC_URL \
            --private-key $PRIVATE_KEY
        ;;
    deposit)
        AMOUNT=$2
        if [ -z "$AMOUNT" ]; then
            echo -e "${YELLOW}Usage: ./scripts/dice-fate-cli.sh deposit <amount_eth>${NC}"
            exit 1
        fi
        echo -e "${BLUE}Depositing ${AMOUNT} ETH to house...${NC}"
        cast send $DICE_FATE_CONTRACT \
            "depositHouse()" \
            --value ${AMOUNT}ether \
            --rpc-url $RPC_URL \
            --private-key $PRIVATE_KEY
        ;;
    withdraw)
        AMOUNT=$2
        if [ -z "$AMOUNT" ]; then
            echo -e "${YELLOW}Usage: ./scripts/dice-fate-cli.sh withdraw <amount_eth>${NC}"
            exit 1
        fi
        AMOUNT_WEI=$(cast to-wei $AMOUNT ether)
        echo -e "${BLUE}Withdrawing ${AMOUNT} ETH from house...${NC}"
        cast send $DICE_FATE_CONTRACT \
            "withdrawHouse(uint256)" \
            $AMOUNT_WEI \
            --rpc-url $RPC_URL \
            --private-key $PRIVATE_KEY
        ;;
    *)
        echo -e "${YELLOW}Unknown command: $COMMAND${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✓ Complete${NC}"
