-include .env

.PHONY: all build test test-v coverage fmt snapshot anvil deploy-anvil clean

# Anvil's default account 0. This key is public and only valid on a local Anvil chain.
# Never use it, or any key, on a real network from this file.
ANVIL_RPC_URL := http://127.0.0.1:8545
ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

all: clean build test

build:
	forge build

test:
	forge test

# Verbose test output with traces for failures
test-v:
	forge test -vvvv

# Coverage of src/ only (excludes scripts and tests from the report)
coverage:
	forge coverage --no-match-coverage "(script|test)"

fmt:
	forge fmt

# Gas snapshot of every test, saved to .gas-snapshot
snapshot:
	forge snapshot

# Start a local chain (run in its own terminal)
anvil:
	anvil

deploy-anvil:
	forge script script/DeployLeagueTreasury.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_KEY) --broadcast

clean:
	forge clean