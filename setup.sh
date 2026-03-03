#!/bin/bash

# DiceFate Local Deployment Script
# This script automates setting up Anvil and deploying the contract

set -e

echo "🎲 DiceFate Deployment Script"
echo "=============================="

# Check for required tools
echo "Checking for required tools..."
command -v foundryup >/dev/null 2>&1 || { echo "❌ Foundry not installed. Run: curl -L https://foundry.paradigm.xyz | bash"; exit 1; }
command -v node >/dev/null 2>&1 || { echo "❌ Node.js not installed"; exit 1; }

echo "✅ All tools found"

# Setup contracts
echo ""
echo "Setting up Foundry project..."
cd contracts
[ ! -d "lib/forge-std" ] && forge install foundry-rs/forge-std
[ ! -d "lib/chainlink" ] && forge install smartcontractkit/chainlink-brownie-contracts

echo "✅ Foundry dependencies installed"

# Build
echo ""
echo "Building contracts..."
forge build
echo "✅ Build complete"

# Run tests
echo ""
echo "Running tests..."
forge test -v
echo "✅ Tests passed"

cd ..

# Setup frontend
echo ""
echo "Setting up frontend..."
cd frontend
npm install
echo "✅ Frontend dependencies installed"

cd ..

# Instructions
echo ""
echo "=============================="
echo "✅ Setup Complete!"
echo "=============================="
echo ""
echo "Next steps:"
echo ""
echo "1. Start Anvil in Terminal 1:"
echo "   make anvil"
echo ""
echo "2. Deploy contract in Terminal 2:"
echo "   cd contracts"
echo "   export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb476cad3623e5f21a2f9f5f8e5e8"
echo "   make deploy-local"
echo ""
echo "3. Update contract address in frontend/lib/config.ts"
echo ""
echo "4. Start frontend in Terminal 3:"
echo "   cd frontend"
echo "   npm run dev"
echo ""
echo "5. Visit http://localhost:3000"
echo ""
