# On-Chain Commish: frontend

React + TypeScript (Vite) app for the LeagueTreasury contract. wagmi + viem for chain reads and writes, RainbowKit for wallets, shadcn/ui (Base UI) components, Tailwind v4 with design tokens in `src/index.css`.

## Run locally

From the repo root:

```bash
make anvil          # terminal 1: local chain with 20 funded accounts
make deploy-anvil   # terminal 2: deploy the contract
make abi            # copy the contract ABI into the frontend
make dev-wallet     # start the app at http://localhost:5173 as an Anvil test account
```

`make dev-wallet` needs no MetaMask. Pick which Anvil account you are from the dropdown in the header, or add `?as=3` to any URL. Use it to play every role: commissioner, members, reporter.

Every league's standings reporter is the standings bot's wallet, set by `VITE_REPORTER_ADDRESS`. Locally it defaults to Anvil account 19, which `make report` signs as. Leave account 19 out of your leagues; it can't join one.

For production, make a fresh wallet just for the bot (`cast wallet new`), put its address in `VITE_REPORTER_ADDRESS`, and keep its private key only where the bot runs (`REPORTER_PRIVATE_KEY`). Don't use a personal wallet: its key has to live on a server, and the reporter can't play in leagues.

To use a real wallet instead, run `make dev`, add the Anvil network to MetaMask (RPC `http://127.0.0.1:8545`, chain id `31337`) and import an Anvil account's private key. If you restart Anvil, clear MetaMask's activity for that account (Settings > Advanced > Clear activity tab data) or its nonce will be wrong.

## ESPN data

The app reads standings from ESPN for leagues that are **viewable to the public** (a setting in ESPN's league settings). Private leagues aren't supported.

- `server/espn.mjs` fetches a league from ESPN and trims it to names, records and ranks. The dev server serves it at `/api/espn/<sport>/<season>/<leagueId>` (see `vite.config.ts`), because browsers can't call ESPN directly.
- Responses are cached until the weekly matchup rollover: Tuesday 9am ET for football, Monday 9am ET for the other sports.
- Each league records its ESPN league ID, sport and season on-chain, so the app and the bot know which league to read. Paste the league's ESPN URL in the create form and it fills in all three.
- To work offline, serve the sample league instead of calling ESPN:
  ```bash
  ESPN_FIXTURE=server/fixtures/sample-league.json make dev-wallet
  ```

## Standings bot

`scripts/report.mjs` posts a league's final ESPN standings on-chain as its reporter. It always fetches fresh from ESPN, never the cache.

```bash
make report LEAGUE=0          # posts only once ESPN marks the season final
make report LEAGUE=0 TEST=1   # posts the current standings now, for testing
```

Locally it signs as Anvil account 19, the reporter the create form suggests in dev wallet mode. On any other network it requires `REPORTER_PRIVATE_KEY` and won't use Anvil's public keys.

## Layout

```
src/
  index.css            design tokens (colors, type scale) and shadcn theme mapping
  components/ui/       shadcn primitives: button, card, input, label, table, badge, alert, separator
  components/          app-wide pieces: PageShell, FormField, TxButton, Stat, CopyField, ...
  components/league/   league page pieces; actions/ has one card per thing a user can do
  components/create/   create-league form
  hooks/               chain reads (useLeague, useLeagueMembers, useMyLeagues), useTx, useChainNow
  lib/                 league rules mirrored from the contract, payouts, formatting, error messages
  config/              contract address, wagmi config, dev wallet
server/                ESPN fetch + cache, served by the dev server
scripts/               sync-abi, standings bot
  pages/               one file per route
```

`LeagueActions` decides which action card to show from the league's state, the chain time and your role, mirroring the contract so buttons only appear when the transaction would succeed.
