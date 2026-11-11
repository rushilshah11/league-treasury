-include .env

.PHONY: all build test test-v coverage fmt snapshot anvil deploy-anvil deploy-sepolia deploy-base-sepolia deployment-info clean abi frontend-install dev dev-wallet report

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
	forge snapshot --no-match-test "testFuzz_" --no-match-contract Invariant

# Start a local chain (run in its own terminal).
# 20 funded accounts so a full 14-team league can be tested locally.
anvil:
	anvil --accounts 20

deploy-anvil:
	forge script script/DeployLeagueTreasury.s.sol --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_KEY) --broadcast

# Deploy to Ethereum Sepolia and verify the source on Etherscan.
# Needs SEPOLIA_RPC_URL, ETHERSCAN_API_KEY and DEPLOYER_ADDRESS in .env, and your
# deployer imported into Foundry's encrypted keystore once:
#   cast wallet import deployer --interactive
# You'll be asked for the keystore password; no private key is stored in this repo.
DEPLOYER_ACCOUNT ?= deployer
deploy-sepolia:
	forge script script/DeployLeagueTreasury.s.sol --rpc-url $(SEPOLIA_RPC_URL) \
		--account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) --broadcast \
		--verify --etherscan-api-key $(ETHERSCAN_API_KEY)
	@cd frontend && node scripts/deployment-info.mjs 11155111

# Deploy to Base Sepolia (chain id 84532) and verify on BaseScan. Same setup as above, plus
# BASE_SEPOLIA_RPC_URL in .env. The Etherscan V2 API key also works for BaseScan.
deploy-base-sepolia:
	forge script script/DeployLeagueTreasury.s.sol --rpc-url $(BASE_SEPOLIA_RPC_URL) \
		--account $(DEPLOYER_ACCOUNT) --sender $(DEPLOYER_ADDRESS) --broadcast \
		--verify --etherscan-api-key $(ETHERSCAN_API_KEY)
	@cd frontend && node scripts/deployment-info.mjs 84532

# Print the contract address and deploy block for the app and the bot.
deployment-info:
	@cd frontend && node scripts/deployment-info.mjs 11155111

clean:
	forge clean

# ---------- Frontend ----------

# Rebuild the contract and copy its ABI into the frontend
abi:
	forge build
	cd frontend && node scripts/sync-abi.mjs

frontend-install:
	cd frontend && npm install

# Start the frontend dev server at http://localhost:5173
dev:
	cd frontend && npm run dev

# Same as dev, but acts as an Anvil test account without MetaMask.
# Switch accounts from the dropdown in the header, or add ?as=3 to the URL.
# LOCAL CHAIN ONLY.
dev-wallet:
	cd frontend && VITE_DEV_WALLET=true npm run dev

# Standings bot: post a league's final ESPN standings as its reporter.
#   make report                   every league the bot reports for (local chain)
#   make report LEAGUE=0          one league; posts only once ESPN marks the season final
#   make report LEAGUE=0 TEST=1   posts current standings now (local testing)
report:
	cd frontend && node scripts/report.mjs $(if $(LEAGUE),$(LEAGUE),--all) $(if $(TEST),--test,)
