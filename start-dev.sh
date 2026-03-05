#!/bin/bash

# 🎲 DiceFate One-Command Start Script
# Automates: Anvil start → Contract deployment → Frontend launch
# Usage: ./start-dev.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         🎲 DiceFate - One-Command Startup Script 🎲        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Configuration
ANVIL_PORT=8545
ANVIL_HOST="127.0.0.1"
RPC_URL="http://${ANVIL_HOST}:${ANVIL_PORT}"
DEPLOYER_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8"
DEPLOYER_ADDR="0xd21C0c164Ffe0666b92eF93e62D7d80b0F737d57"
FUNDOR_ADDR="0xf39Fd6e51aad88f6f4ce6aB8827279cffFb92266"
INITIAL_FUND="100"
HOUSE_FUND="10"

# Step counters
STEP=1
TOTAL_STEPS=7

# Helper functions
step_start() {
    echo -e "\n${BLUE}[${STEP}/${TOTAL_STEPS}]${NC} $1"
    STEP=$((STEP + 1))
}

step_done() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check dependencies
step_start "Checking dependencies..."
command -v foundryup >/dev/null 2>&1 || error "Foundry not found. Install: curl -L https://foundry.paradigm.xyz | bash"
command -v anvil >/dev/null 2>&1 || error "Anvil not found. Run: foundryup"
command -v cast >/dev/null 2>&1 || error "Cast not found. Run: foundryup"
command -v node >/dev/null 2>&1 || error "Node.js not found. Install from https://nodejs.org"
command -v npm >/dev/null 2>&1 || error "npm not found"
step_done "All dependencies present"

# Check if Anvil is already running
step_start "Checking Anvil status..."
if cast block-number --rpc-url ${RPC_URL} > /dev/null 2>&1; then
    step_done "Anvil already running on ${RPC_URL}"
else
    echo "Starting Anvil..."
    anvil --host ${ANVIL_HOST} --port ${ANVIL_PORT} > /tmp/anvil.log 2>&1 &
    ANVIL_PID=$!
    echo "Anvil process started (PID: $ANVIL_PID)"
    
    # Wait for Anvil to be ready
    echo "Waiting for Anvil to start..."
    for i in {1..30}; do
        if cast block-number --rpc-url ${RPC_URL} > /dev/null 2>&1; then
            echo "Anvil is ready!"
            step_done "Anvil started successfully"
            break
        fi
        if [ $i -eq 30 ]; then
            error "Anvil failed to start. Check /tmp/anvil.log"
        fi
        sleep 1
    done
fi

# Fund deployer account
step_start "Funding deployer account..."
DEPLOYER_BALANCE=$(cast balance ${DEPLOYER_ADDR} --rpc-url ${RPC_URL} 2>/dev/null || echo "0")
if [ "$DEPLOYER_BALANCE" = "0" ]; then
    echo "Transferring ${INITIAL_FUND} ETH to ${DEPLOYER_ADDR}..."
    cast send ${DEPLOYER_ADDR} --value ${INITIAL_FUND}ether \
        --rpc-url ${RPC_URL} \
        --from ${FUNDOR_ADDR} \
        --unlocked > /dev/null 2>&1
    step_done "Deployer account funded"
else
    step_done "Deployer account already has balance"
fi

# Build contracts
step_start "Building contracts..."
cd contracts
forge build > /dev/null 2>&1
step_done "Contracts built"

# Deploy contracts
step_start "Deploying contracts..."
export PRIVATE_KEY=${DEPLOYER_PK}
forge script script/Deploy.s.sol:Deploy \
    --rpc-url ${RPC_URL} \
    --private-key ${DEPLOYER_PK} \
    -v --broadcast > /dev/null 2>&1

# Extract contract address from broadcast JSON
DICE_FATE_ADDR=$(grep -A 1 '"contractName": "DiceFate"' broadcast/Deploy.s.sol/31337/run-latest.json | grep -o '0x[a-fA-F0-9]*' | head -1)

if [ -z "$DICE_FATE_ADDR" ]; then
    error "Failed to extract contract address from deployment"
fi

step_done "Contracts deployed"
echo -e "    ${BLUE}DiceFate: ${DICE_FATE_ADDR}${NC}"

# Fund house
step_start "Funding game house..."
if cast send ${DICE_FATE_ADDR} "depositHouse()" \
    --value ${HOUSE_FUND}ether \
    --rpc-url ${RPC_URL} \
    --private-key ${DEPLOYER_PK} \
    > /dev/null 2>&1; then
    step_done "House funded with ${HOUSE_FUND} ETH"
else
    warning "Could not fund house (insufficient deployer balance). You can manually fund later."
fi

cd ..

# Update frontend config
step_start "Updating frontend configuration..."
FRONTEND_CONFIG="frontend/lib/config.ts"

# Update the contract address in config
if [ -f "$FRONTEND_CONFIG" ]; then
    # Use a more robust sed command that works on both macOS and Linux
    sed -i.bak "s|export const DICE_FATE_CONTRACT = .*|export const DICE_FATE_CONTRACT = \"${DICE_FATE_ADDR}\";|" "$FRONTEND_CONFIG"
    rm -f "${FRONTEND_CONFIG}.bak"
    step_done "Frontend config updated"
else
    warning "Could not find frontend config at $FRONTEND_CONFIG"
fi

echo -e "\n${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 Setup Complete!${NC}\n"
echo -e "Contract deployed to: ${BLUE}${DICE_FATE_ADDR}${NC}"
echo -e "RPC URL: ${BLUE}${RPC_URL}${NC}"
echo -e "House funded with: ${BLUE}${HOUSE_FUND} ETH${NC}\n"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Open MetaMask and add this network:"
echo -e "     - Name: Localhost 8545"
echo -e "     - RPC: ${RPC_URL}"
echo -e "     - Chain ID: 31337"
echo -e "  2. Import account with private key:"
echo -e "     - ${DEPLOYER_PK}"
echo -e "  3. You'll have 100 ETH to play with"
echo ""
echo -e "${BLUE}Starting frontend...${NC}\n"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}\n"

# Start frontend
cd frontend
npm run dev
