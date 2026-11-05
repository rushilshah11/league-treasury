// Standings bot: posts a league's final ESPN standings on-chain as its reporter.
//
//   node scripts/report.mjs <leagueId>          post once ESPN says the season is final
//   node scripts/report.mjs <leagueId> --test   post the current standings now (testing only)
//
// From the repo root: make report LEAGUE=0  (add TEST=1 for --test).
//
// Locally it signs as Anvil account 19, the reporter the create form suggests in
// dev wallet mode. On any other network it needs REPORTER_PRIVATE_KEY and refuses
// to use Anvil's public keys.

import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createPublicClient, createWalletClient, http, isAddressEqual } from 'viem'
import { mnemonicToAccount, privateKeyToAccount } from 'viem/accounts'
import { anvil } from 'viem/chains'
import { SPORT_CODES, fetchEspnLeague } from '../server/espn.mjs'

const here = dirname(fileURLToPath(import.meta.url))
const { abi } = JSON.parse(readFileSync(resolve(here, '../../out/LeagueTreasury.sol/LeagueTreasury.json'), 'utf8'))

const RPC_URL = process.env.RPC_URL ?? 'http://127.0.0.1:8545'
const ADDRESS = process.env.VITE_TREASURY_ADDRESS ?? '0x5FbDB2315678afecb367f032d93F642f64180aa3'
const ANVIL_MNEMONIC = 'test test test test test test test test test test test junk'
const ACTIVE = 1 // LeagueState.ACTIVE

function fail(message) {
  console.error(`✗ ${message}`)
  process.exit(1)
}

function reporterAccount() {
  if (process.env.REPORTER_PRIVATE_KEY) return privateKeyToAccount(process.env.REPORTER_PRIVATE_KEY)
  const local = /^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?/.test(RPC_URL)
  if (!local) fail('Set REPORTER_PRIVATE_KEY. Anvil test keys are only for a local chain.')
  return mnemonicToAccount(ANVIL_MNEMONIC, { addressIndex: 19 })
}

const [leagueArg, ...flags] = process.argv.slice(2)
if (!/^\d+$/.test(leagueArg ?? '')) fail('Usage: node scripts/report.mjs <leagueId> [--test]')
const leagueId = BigInt(leagueArg)
const testMode = flags.includes('--test')

const contract = { address: ADDRESS, abi }
const publicClient = createPublicClient({ chain: anvil, transport: http(RPC_URL) })
const account = reporterAccount()
const walletClient = createWalletClient({ account, chain: anvil, transport: http(RPC_URL) })

// 1. The league on-chain
const [, , teamCount, , state, reporter] = await publicClient.readContract({
  ...contract,
  functionName: 'leagues',
  args: [leagueId],
})
const [created] = await publicClient.getContractEvents({
  ...contract,
  eventName: 'LeagueCreated',
  args: { leagueId },
  fromBlock: 0n,
})
if (!created) fail(`League ${leagueId} doesn't exist.`)
const { name, espnLeagueId, espnSeason, sport } = created.args
const sportCode = SPORT_CODES[sport]
console.log(`League ${leagueId}: ${name} (ESPN ${sportCode} ${espnSeason}, league ${espnLeagueId})`)

if (!isAddressEqual(reporter, account.address)) fail(`This bot signs as ${account.address}, but the league's reporter is ${reporter}.`)
if (state !== ACTIVE) {
  console.log('Nothing to do: the league is not in season (it may not be full, or standings are already posted).')
  process.exit(0)
}

// 2. Fresh standings from ESPN (never the dev server's weekly cache: money follows this)
const espn = await fetchEspnLeague(espnLeagueId, { sport: sportCode, season: espnSeason }).catch((e) => fail(e.message))
if (!espn.isFinal && !testMode) {
  console.log(`Season isn't over (matchup ${espn.currentMatchupPeriod} of ${espn.finalMatchupPeriod}). Nothing posted.`)
  process.exit(0)
}
if (!espn.isFinal) console.log('--test: posting current standings, not final ones.')

// 3. Every joined team, in ESPN's order
const joined = await publicClient.getContractEvents({
  ...contract,
  eventName: 'MemberJoined',
  args: { leagueId },
  fromBlock: 0n,
})
const joinedTeams = new Set(joined.map((log) => Number(log.args.teamId)))
const ranking = espn.teams.filter((team) => joinedTeams.has(team.id))
if (ranking.length !== teamCount || ranking.length !== joinedTeams.size) {
  fail(`ESPN's teams don't match the league's: ${ranking.length} matched, ${teamCount} expected.`)
}

ranking.forEach((team, i) => console.log(`  ${i + 1}. ${team.name} (team ${team.id})`))

// 4. Post it
const { request } = await publicClient
  .simulateContract({ ...contract, account, functionName: 'submitStandings', args: [leagueId, ranking.map((t) => t.id)] })
  .catch((e) => fail(e.shortMessage ?? e.message))
const hash = await walletClient.writeContract(request)
const receipt = await publicClient.waitForTransactionReceipt({ hash })
if (receipt.status !== 'success') fail(`Transaction ${hash} reverted.`)
console.log(`✓ Standings posted (tx ${hash}). Members have 48 hours to dispute.`)
