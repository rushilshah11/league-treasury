# On-Chain Commish

**The commissioner every fantasy league can trust.**

Fantasy league buy-ins usually sit in one person's Venmo until the season ends. On-Chain Commish holds them in a smart contract instead, then pays every team out by its final ESPN standings. No one can run off with the pot, including the commissioner.

[![Demo: a full season, start to payout](frontend/public/demo/walkthrough-poster.jpg)](frontend/public/demo/walkthrough.mp4)

*A full season in 40 seconds: create a league from an ESPN link, managers join, live standings, final standings posted on-chain, payouts claimed.*

- **Live app:** [onchaincommissioner.vercel.app](https://onchaincommissioner.vercel.app) (Base Sepolia testnet, test USDC only)
- **Contract:** [`0x2711…d2ad` on BaseScan](https://sepolia.basescan.org/address/0x2711e4e095f4fddee31f3ae7125acc4521c6d2ad#code) (verified source). An earlier version of the contract, which took test ETH, is still on Ethereum Sepolia at [`0xd39e…508F`](https://sepolia.etherscan.io/address/0xd39e4462F49009C15702638A7fAd34BC48Fa508F#code).

## How a season works

1. **Create.** The commissioner pastes their ESPN league link. Team names and league size come from ESPN; the commissioner sets the buy-in and deadlines, then pays in as the first team.
2. **Join.** Each manager opens the invite link, picks their ESPN team and pays the buy-in into the contract. The league starts once every team has joined.
3. **Track.** During the season, the league page shows live ESPN standings and what each place would win today.
4. **Settle.** After the season, a standings bot posts ESPN's final ranking on-chain. Members have 48 hours to dispute it.
5. **Get paid.** If no one disputes, anyone can finalize, and every manager claims their share. Payouts are split across all places, so every team gets something back.

## The trust model

The point of the project is that no single person controls the money or the result.

| Risk | How it's handled |
|---|---|
| The commissioner keeps the pot | Buy-ins go straight into the contract. Nothing lets anyone withdraw them except the payout and refund rules. |
| Someone posts fake standings | Only the league's reporter, a neutral bot that copies public ESPN data, can post standings. The reporter can never have a team in the league. |
| The bot gets it wrong | Any member can dispute within 48 hours. Members then vote on corrected standings, and a majority makes them final. The commissioner gets one vote like everyone else. |
| One key controls the standings | A league can name `CreStandingsReceiver` as its reporter instead of the bot's wallet. Only Chainlink's forwarder can call it, and in production only reports from our own workflow are accepted. Chainlink's nodes must agree on the ranking before it reaches the chain, and the 48-hour dispute window still applies. See [Chainlink CRE](#chainlink-cre-optional-reporter). |
| The season falls apart | If the league never fills, standings are never posted, or a dispute isn't resolved within 7 days, everyone can withdraw their full buy-in. |

Payouts use the pull pattern: each member claims their own share, so one wallet that can't receive ETH never blocks the others.

## Architecture

```
ESPN fantasy API (public leagues)
        │
        ├── Serverless function (/api/espn)  ── cached until each week's matchups end
        │        │
        │        ▼
        │   React app (Vite, wagmi, viem, RainbowKit, shadcn/ui)  ◀── players' wallets
        │        │
        ▼        ▼
Standings bot ──▶ LeagueTreasury.sol (Base Sepolia)
(GitHub Actions,     buy-ins, members, standings, disputes, votes, payouts
 runs daily)
```

- **`src/LeagueTreasury.sol`:** the contract. Leagues move through `OPEN → ACTIVE → STANDINGS_SUBMITTED → (DISPUTED →) FINALIZED`, or to `CANCELLED` with refunds. Payout tables are in basis points, and rounding dust goes to first place so payouts always add up to the pot exactly. League info and member lists live in storage, so the app and bot read them with plain calls and work on any RPC plan.
- **`test/`:** 142 Foundry tests (unit, fuzz, invariant and integration), including fuzz tests proving payouts and refunds always sum to exactly what was paid in, invariant tests that run random sequences of joins, standings, disputes, claims and cancellations and check the contract always holds exactly the USDC it owes (never stuck, never insolvent), plus malicious-wallet tests for reentrancy and rejected transfers. CI also runs Slither static analysis and checks the gas snapshot.
- **`frontend/`:** the React app. Design tokens in `src/index.css`, shadcn/ui components, and one action card per thing a user can do, chosen from the league's state, the chain's clock and the viewer's role.
- **`frontend/server/espn.mjs`:** reads ESPN and trims it to names, records and ranks. It runs inside the dev server locally and as a Vercel Function in production (`frontend/api/espn.mjs`).
- **`frontend/scripts/report.mjs`:** the standings bot. It checks every league it reports for, skips each until ESPN marks the season final, then posts the ranking. `.github/workflows/standings-bot.yml` runs it daily.
- **`src/CreStandingsReceiver.sol`:** an optional reporter that Chainlink CRE posts standings through. It forwards them to `LeagueTreasury.submitStandings`, so the treasury itself is unchanged. Covered by its own Foundry tests.
- **`cre/`:** the Chainlink CRE workflow. Every node fetches ESPN, the network must agree on the ranking, and the signed result is sent to the receiver.

## Chainlink CRE (optional reporter)

By default a bot wallet posts the standings, so one key is trusted. The CRE path replaces that key with Chainlink's oracle network.

**How it works:** a workflow in `cre/standings-workflow` runs on a schedule. Every node fetches the league from ESPN and returns the final ranking as a list of team IDs. The network only continues if a majority return the exact same list, and then signs it. Chainlink's forwarder contract delivers the signed report to `CreStandingsReceiver`, which calls `submitStandings` on the treasury. A league uses it by naming the receiver as its reporter when it is created.

**Status:** the workflow is tested in Chainlink's simulator and the receiver is deployed and verified on Base Sepolia, with Foundry tests. Running the workflow live on Chainlink's network needs deploy approval from Chainlink, which is not in place yet. The bot remains the default reporter until then.

**Production checklist** (before any league relies on it):

1. Set the receiver's forwarder to the production forwarder for the chain with `setForwarder`. Simulation uses a mock forwarder that does not check signatures.
2. Set `setExpectedWorkflowOwner` and `setExpectedWorkflowId` to our workflow's owner and ID. The forwarder delivers reports from any workflow aimed at the receiver, so without these checks anyone could post standings through it. They have to stay off while simulating, because the mock forwarder sends no workflow details.
3. Consider calling `renounceOwnership()` once steps 1 and 2 are set. The owner can change the forwarder and turn the workflow checks off, so it is still a trusted key until ownership is renounced. The dispute window limits the damage in the meantime.
4. Point the app's `VITE_REPORTER_ADDRESS` at the receiver so new leagues use it, and update the form text that says a bot posts the standings.
5. Set the workflow config to require a final season (`allowNonFinal: false`) and make sure the receiver address in it is correct.

## Run it locally

Requires [Foundry](https://book.getfoundry.sh) and Node 20+.

```bash
make frontend-install
make anvil                                  # terminal 1: local chain, 20 funded accounts
make deploy-anvil && make abi && make dev-wallet   # terminal 2: app at http://localhost:5173
```

`make dev-wallet` lets you act as any test account from a dropdown, so you can play commissioner and every manager without MetaMask. Post standings locally with `make report LEAGUE=0` (add `TEST=1` to post a season that isn't over yet).

```bash
make test        # contract tests
make coverage    # coverage report
```

Deploying to Base Sepolia and Vercel is covered step by step in [DEPLOY.md](DEPLOY.md).

## Stack

- **Contract:** Solidity 0.8, Foundry
- **App:** React 19, TypeScript, Vite, Tailwind CSS v4, shadcn/ui (Base UI)
- **Web3:** wagmi, viem, RainbowKit
- **Infrastructure:** Vercel Functions, GitHub Actions, Base Sepolia

Test network only. No real money.
