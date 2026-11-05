# Deploying On-Chain Commish

The contract goes on **Ethereum Sepolia** (a testnet: test ETH only), the app on **Vercel**,
and the standings bot runs daily on **GitHub Actions**.

## 1. Accounts (free, one time)

- **Alchemy** (alchemy.com): create an app on Ethereum Sepolia and copy its HTTPS URL. This is your RPC: how the app and the bot talk to the chain.
- **Etherscan** (etherscan.io/myapikey): an API key, so the deploy can publish the contract's source code on Etherscan.
- **Vercel** (vercel.com): sign in with GitHub.

## 2. Wallets

| Wallet | What it does | Where its key lives |
|---|---|---|
| Deployer | Deploys the contract once. Has no special power afterward. | Foundry's encrypted keystore on your computer |
| You | Commissioner and player | MetaMask |
| Bot | Posts every league's final standings. Can never play. | GitHub secret, plus a backup in your password manager |

- **Deployer:** export a MetaMask account's private key (Account details → Show private key) and import it:
  ```bash
  cast wallet import deployer --interactive   # paste the key, choose a password
  cast wallet address --account deployer      # prints its address
  ```
- **Bot:** make a brand-new wallet. Don't reuse a personal one.
  ```bash
  cast wallet new
  ```
  Save the address and private key in your password manager, then send the address about 0.01 Sepolia ETH from MetaMask for gas.

## 3. Deploy the contract

Copy `.env.example` to `.env` in the repo root and fill it in (`SEPOLIA_RPC_URL`, `ETHERSCAN_API_KEY`, `DEPLOYER_ADDRESS`). Then:

```bash
make deploy-sepolia
```

Type the keystore password when asked. When it finishes it prints the contract's Etherscan link and the values for the next steps. Run `make deployment-info` to see them again.

If verification fails with an Etherscan API error, update Foundry (`foundryup`) and run `make deploy-sepolia` again; Etherscan retired its old API.

## 4. Deploy the app on Vercel

1. Vercel → Add New → Project → import the `league-treasury` repo.
2. **Root Directory: `frontend`**. Vercel detects Vite; keep the default build settings.
3. Environment Variables:

   | Name | Value |
   |---|---|
   | `VITE_CHAIN` | `sepolia` |
   | `VITE_TREASURY_ADDRESS` | from `make deployment-info` |
   | `VITE_DEPLOY_BLOCK` | from `make deployment-info` |
   | `VITE_REPORTER_ADDRESS` | the bot's address (not its key) |
   | `VITE_RPC_URL` | your Alchemy URL |

   Everything starting with `VITE_` ends up in the browser, so never put a private key there. Your Alchemy URL will be visible too; in Alchemy's app settings, limit it to your Vercel domain.
4. Deploy. In MetaMask, switch to the Sepolia network before connecting.

The ESPN endpoint (`frontend/api/espn.mjs`) deploys with the site as a Vercel Function. `frontend/vercel.json` routes `/api/espn/...` to it and sends every other path, like invite links, to the app.

## 5. Turn on the standings bot

GitHub repo → Settings → Secrets and variables → Actions:

- **Secrets:** `SEPOLIA_RPC_URL` (your Alchemy URL) and `REPORTER_PRIVATE_KEY` (the bot's key)
- **Variables:** `TREASURY_ADDRESS` and `DEPLOY_BLOCK` (from `make deployment-info`)

Then Actions → Standings bot → Run workflow, to check it works. With no leagues yet it prints "No leagues use this bot as their reporter yet."

It then runs daily. Each league is skipped until ESPN marks its season final. Note: GitHub pauses scheduled workflows after 60 days with no commits to the repo; re-enable it from the Actions tab if that happens.
