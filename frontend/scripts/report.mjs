// Standings bot: posts leagues' final ESPN standings on-chain as their reporter.
//
//   node scripts/report.mjs --all             every league this bot reports for (what the scheduler runs)
//   node scripts/report.mjs <leagueId>        one league
//   add --test                                post current standings even if the season isn't over (local testing)
//
// From the repo root: make report LEAGUE=0  (add TEST=1 for --test).
//
// Settings (environment variables):
//   CHAIN                 anvil (default), sepolia or base-sepolia
//   RPC_URL               defaults to http://127.0.0.1:8545 on anvil, the public endpoint on sepolia
//   TREASURY_ADDRESS      the deployed contract (required off anvil)
//   REPORTER_PRIVATE_KEY  the bot wallet's key (required off anvil; locally Anvil account 19 is used)

import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createPublicClient, createWalletClient, http, isAddressEqual } from 'viem'
import { mnemonicToAccount, privateKeyToAccount } from 'viem/accounts'
import { anvil, baseSepolia, sepolia } from 'viem/chains'
import { SPORT_CODES, fetchEspnLeague } from '../server/espn.mjs'

const here = dirname(fileURLToPath(import.meta.url))
const abi = JSON.parse(readFileSync(resolve(here, '../src/abi/leagueTreasuryAbi.json'), 'utf8'))

const CHAINS = { anvil, sepolia, 'base-sepolia': baseSepolia }
const chain = CHAINS[process.env.CHAIN ?? 'anvil']
if (!chain) fail(`Unknown CHAIN "${process.env.CHAIN}". Use anvil, sepolia or base-sepolia.`)
const isLocal = chain.id === anvil.id

const RPC_URL = process.env.RPC_URL || (isLocal ? 'http://127.0.0.1:8545' : undefined)
const ADDRESS = process.env.TREASURY_ADDRESS || (isLocal ? '0x5FbDB2315678afecb367f032d93F642f64180aa3' : undefined)
if (!ADDRESS) fail('Set TREASURY_ADDRESS to the deployed contract.')
const ACTIVE = 1 // LeagueState.ACTIVE
const ANVIL_MNEMONIC = 'test test test test test test test test test test test junk'

function fail(message) {
  console.error(`✗ ${message}`)
  process.exit(1)
}

/** Accepts a key with or without the 0x prefix (MetaMask exports it without), ignoring stray whitespace. */
function normalizeKey(raw) {
  const hex = raw.trim().replace(/^0x/i, '')
  if (!/^[0-9a-fA-F]{64}$/.test(hex)) {
    fail(`REPORTER_PRIVATE_KEY must be 64 hex characters (with or without 0x); got ${hex.length} characters.`)
  }
  return `0x${hex}`
}

function reporterAccount() {
  if (process.env.REPORTER_PRIVATE_KEY) return privateKeyToAccount(normalizeKey(process.env.REPORTER_PRIVATE_KEY))
  if (!isLocal) fail('Set REPORTER_PRIVATE_KEY. Anvil test keys are only for a local chain.')
  return mnemonicToAccount(ANVIL_MNEMONIC, { addressIndex: 19 })
}

const args = process.argv.slice(2)
const testMode = args.includes('--test')
const all = args.includes('--all')
const leagueArg = args.find((a) => /^\d+$/.test(a))
if (!all && !leagueArg) fail('Usage: node scripts/report.mjs <leagueId> | --all [--test]')

const contract = { address: ADDRESS, abi }
const publicClient = createPublicClient({ chain, transport: http(RPC_URL) })
const account = reporterAccount()
const walletClient = createWalletClient({ account, chain, transport: http(RPC_URL) })

const read = (functionName, args) => publicClient.readContract({ ...contract, functionName, args })

/** Posts one league's standings if it's in season and ESPN's season is final. Everything is read from contract storage. */
async function report(leagueId, { teamCount, state }) {
  const [name, link] = await read('getLeagueInfo', [leagueId])
  const sportCode = SPORT_CODES[link.sport]
  console.log(`\nLeague ${leagueId}: ${name} (ESPN ${sportCode} ${link.season}, league ${link.leagueId})`)
  if (state !== ACTIVE) return console.log('  Not in season (not full yet, or standings already posted). Skipped.')

  // Fresh from ESPN, never a cache: money follows this.
  const espn = await fetchEspnLeague(link.leagueId, { sport: sportCode, season: link.season })
  if (!espn.isFinal && !testMode) {
    return console.log(`  Season isn't over (matchup ${espn.currentMatchupPeriod} of ${espn.finalMatchupPeriod}). Nothing posted.`)
  }
  if (!espn.isFinal) console.log('  --test: posting current standings, not final ones.')

  const [, records] = await read('getMembers', [leagueId])
  const joinedTeams = new Set(records.map((member) => Number(member.teamId)))
  const ranking = espn.teams.filter((team) => joinedTeams.has(team.id))
  if (ranking.length !== teamCount || ranking.length !== joinedTeams.size) {
    throw new Error(`ESPN's teams don't match the league's: ${ranking.length} matched, ${teamCount} expected.`)
  }
  ranking.forEach((team, i) => console.log(`  ${i + 1}. ${team.name} (team ${team.id})`))

  const { request } = await publicClient.simulateContract({
    ...contract,
    account,
    functionName: 'submitStandings',
    args: [leagueId, ranking.map((t) => t.id)],
  })
  const hash = await walletClient.writeContract(request)
  const receipt = await publicClient.waitForTransactionReceipt({ hash })
  if (receipt.status !== 'success') throw new Error(`Transaction ${hash} reverted.`)
  console.log(`  ✓ Standings posted (tx ${hash}). Members have 48 hours to dispute.`)
}

console.log(`Standings bot on ${chain.name} as ${account.address}`)

// The leagues to check: one by ID, or every league naming this bot as reporter.
// League IDs count up from 0, so the bot walks them and reads each one directly.
const nextLeagueId = await read('nextLeagueId', [])
const ids = all ? Array.from({ length: Number(nextLeagueId) }, (_, i) => BigInt(i)) : [BigInt(leagueArg)]
if (!all && ids[0] >= nextLeagueId) fail(`League ${leagueArg} doesn't exist.`)

const leagues = []
for (const id of ids) {
  const [, , teamCount, , state, reporter] = await read('leagues', [id])
  if (isAddressEqual(reporter, account.address)) leagues.push({ id, teamCount, state })
  else if (!all) fail(`This bot signs as ${account.address}, but league ${id}'s reporter is ${reporter}.`)
}
if (all && leagues.length === 0) console.log('No leagues use this bot as their reporter yet.')

let failures = 0
for (const league of leagues) {
  try {
    await report(league.id, league)
  } catch (err) {
    failures++
    console.error(`  ✗ ${err.shortMessage ?? err.message}`)
  }
}
process.exit(failures ? 1 : 0)
