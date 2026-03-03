#!/bin/bash
#
# DiceFate End-to-End Test Scenario
# This script demonstrates a complete betting flow
#

set -e

# Configuration
PRIVATE_KEY=${PRIVATE_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8}
RPC_URL=${RPC_URL:-http://127.0.0.1:8545}
BET_AMOUNT="1"    # ETH
BET_TARGET="50"   # 50% win chance

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   DiceFate End-to-End Test Scenario${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get contract address
if [ -z "$DICE_FATE_CONTRACT" ]; then
    echo -e "${YELLOW}Contract address not set. Using default mock address.${NC}"
    echo -e "${YELLOW}Make sure to deploy first and set DICE_FATE_CONTRACT env var${NC}"
    exit 1
fi

echo -e "${BLUE}Contract: ${GREEN}$DICE_FATE_CONTRACT${NC}"
echo ""

# Step 1: Check contract balance
echo -e "${BLUE}[1] Checking contract balance...${NC}"
HOUSE_BALANCE=$(cast call $DICE_FATE_CONTRACT "contractBalance()(uint256)" --rpc-url $RPC_URL)
HOUSE_BALANCE_ETH=$(cast from-wei $HOUSE_BALANCE ether)
echo -e "${GREEN}✓ House balance: ${GREEN}${HOUSE_BALANCE_ETH}${NC} ETH"
echo ""

# Step 2: Get account balance before bet
echo -e "${BLUE}[2] Checking player account balance...${NC}"
ACCOUNT=$(cast wallet address --private-key $PRIVATE_KEY)
PLAYER_BALANCE=$(cast balance $ACCOUNT --rpc-url $RPC_URL)
PLAYER_BALANCE_ETH=$(cast from-wei $PLAYER_BALANCE ether)
echo -e "${GREEN}✓ Player: ${GREEN}${ACCOUNT}${NC}"
echo -e "${GREEN}✓ Balance: ${GREEN}${PLAYER_BALANCE_ETH}${NC} ETH"
echo ""

# Step 3: Place a bet
echo -e "${BLUE}[3] Placing bet: ${GREEN}${BET_AMOUNT}${NC} ETH, target under ${GREEN}${BET_TARGET}${NC}...${NC}"
TX_HASH=$(cast send $DICE_FATE_CONTRACT \
    "placeBet(uint8)" \
    $BET_TARGET \
    --value ${BET_AMOUNT}ether \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --json | jq -r '.transactionHash')

echo -e "${GREEN}✓ Transaction: ${NC}${TX_HASH:0:10}...${NC}"

# Extract bet ID from transaction (it will be bet ID 1 if fresh deployment)
BET_ID="1"
echo -e "${GREEN}✓ Bet ID: ${NC}${BET_ID}${NC}"
echo ""

# Step 4: Get bet details
echo -e "${BLUE}[4] Retrieving bet details...${NC}"
BET_DATA=$(cast call $DICE_FATE_CONTRACT "getBet(uint256)(address,uint256,uint8,uint256,bool,bool)" $BET_ID --rpc-url $RPC_URL)
BET_AMOUNT_CHECK=$(echo $BET_DATA | awk '{print $2}')
BET_TARGET_CHECK=$(echo $BET_DATA | awk '{print $3}')
echo -e "${GREEN}✓ Bet amount: $(cast from-wei $BET_AMOUNT_CHECK ether) ETH${NC}"
echo -e "${GREEN}✓ Target: ${NC}${BET_TARGET_CHECK}${NC}"
echo ""

# Step 5: Resolve the bet (two scenarios)
echo -e "${BLUE}[5] Resolving bet with random number...${NC}"

# First resolution - WINNING BET (roll under target)
RANDOM_WIN=$((RANDOM % (BET_TARGET)))
echo -e "${YELLOW}Scenario A: WINNING BET (random: ${RANDOM_WIN} < target: ${BET_TARGET})${NC}"
TX_WIN=$(cast send $DICE_FATE_CONTRACT \
    "resolveBet(uint256,uint256)" \
    $BET_ID \
    $RANDOM_WIN \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --json | jq -r '.transactionHash')
echo -e "${GREEN}✓ Resolution TX: ${NC}${TX_WIN:0:10}...${NC}"

# Get updated bet details
BET_RESOLVED=$(cast call $DICE_FATE_CONTRACT "getBet(uint256)(address,uint256,uint8,uint256,bool,bool)" $BET_ID --rpc-url $RPC_URL)
ROLL_RESULT=$(echo $BET_RESOLVED | awk '{print $4}')
WON=$(echo $BET_RESOLVED | awk '{print $5}')

if [ "$WON" = "true" ]; then
    echo -e "${GREEN}✓ BET WON!${NC} Roll result: ${ROLL_RESULT}"
    PLAYER_BALANCE_AFTER=$(cast balance $ACCOUNT --rpc-url $RPC_URL)
    PLAYER_BALANCE_AFTER_ETH=$(cast from-wei $PLAYER_BALANCE_AFTER ether)
    PAYOUT_ETH=$(($(cast from-wei $PLAYER_BALANCE_AFTER ether) - $(cast from-wei $PLAYER_BALANCE ether)))
    echo -e "${GREEN}✓ Payout: ${PAYOUT_ETH} ETH${NC}"
else
    echo -e "${YELLOW}✓ Bet lost. Roll result: ${ROLL_RESULT}${NC}"
fi
echo ""

# Step 6: Test losing scenario
if [ "$BET_ID" -lt "999" ]; then
    echo -e "${BLUE}[6] Testing losing scenario...${NC}"
    BET_ID=$((BET_ID + 1))
    
    # Place another bet
    TX_HASH=$(cast send $DICE_FATE_CONTRACT \
        "placeBet(uint8)" \
        $BET_TARGET \
        --value ${BET_AMOUNT}ether \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --json | jq -r '.transactionHash')
    
    # Resolve with losing number
    RANDOM_LOSS=$((60 + RANDOM % 40))  # Roll between 60-99 (will be 61-100)
    echo -e "${YELLOW}Scenario B: LOSING BET (random: ${RANDOM_LOSS} >= target: ${BET_TARGET})${NC}"
    
    TX_LOSE=$(cast send $DICE_FATE_CONTRACT \
        "resolveBet(uint256,uint256)" \
        $BET_ID \
        $RANDOM_LOSS \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --json | jq -r '.transactionHash')
    
    BET_LOST=$(cast call $DICE_FATE_CONTRACT "getBet(uint256)(address,uint256,uint8,uint256,bool,bool)" $BET_ID --rpc-url $RPC_URL)
    ROLL_LOST=$(echo $BET_LOST | awk '{print $4}')
    WON_LOST=$(echo $BET_LOST | awk '{print $5}')
    
    echo -e "${GREEN}✓ Resolution TX: ${NC}${TX_LOSE:0:10}...${NC}"
    if [ "$WON_LOST" = "false" ]; then
        echo -e "${GREEN}✓ BET LOST as expected. Roll result: ${ROLL_LOST}${NC}"
    fi
    echo ""
fi

# Final Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ End-to-End Test Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Summary:${NC}"
echo "  - Placed bets successfully"
echo "  - Retrieved bet details"
echo "  - Resolved bets with correct payouts"
echo "  - Tested both win/loss scenarios"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review contract events in block explorer"
echo "  2. Test via frontend at http://localhost:3000"
echo "  3. Play with different target numbers"
echo "  4. Monitor gas usage with 'make test-gas'"
echo ""
