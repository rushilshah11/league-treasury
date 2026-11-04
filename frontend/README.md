# League Treasury: frontend

React + TypeScript (Vite) app for the LeagueTreasury contract, using wagmi, viem and RainbowKit.

## Run locally

From the repo root:

```bash
make anvil          # terminal 1: local chain
make deploy-anvil   # terminal 2: deploy the contract
make abi            # copy the contract ABI into the frontend
make dev            # start the app at http://localhost:5173
```

Then add the Anvil network to MetaMask (RPC `http://127.0.0.1:8545`, chain id `31337`)
and import Anvil's account 0 private key to get test ETH.
