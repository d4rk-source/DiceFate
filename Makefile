# Foundry Setup
setup:
	cd contracts && \
	forge install foundry-rs/forge-std && \
	forge install smartcontractkit/chainlink-brownie-contracts

# Compilation
build:
	cd contracts && forge build

# Testing
test:
	cd contracts && forge test -v

test-watch:
	cd contracts && forge test --watch

test-gas:
	cd contracts && forge test --gas-report

# Local deployment (Anvil)
anvil:
	anvil

deploy-local:
	cd contracts && forge script script/Deploy.s.sol:Deploy --rpc-url http://localhost:8545 --private-key $(PRIVATE_KEY) -vvv --broadcast

# Cleanup
clean:
	cd contracts && forge clean

# Frontend setup
frontend-install:
	cd frontend && npm install

frontend-dev:
	cd frontend && npm run dev

frontend-build:
	cd frontend && npm run build

.PHONY: setup build test test-watch test-gas anvil deploy-local clean frontend-install frontend-dev frontend-build
