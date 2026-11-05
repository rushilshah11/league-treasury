// Standings bot: posts leagues' final ESPN standings on-chain as their reporter.
//
//   node scripts/report.mjs --all             every league this bot reports for (what the scheduler runs)
//   node scripts/report.mjs <leagueId>        one league
//   add --test                                post current standings even if the season isn't over (local testing)
//
// From the repo root: make report LEAGUE=0  (add TEST=1 for --test).
//
// Settings (environment variables):
//   CHAIN                 anvil (default) or sepolia
//   RPC_URL               defaults to http://127.0.0.1:8545 on anvil, the public endpoint on sepolia
//   TREASURY_ADDRESS      the deployed contract (required off anvil)
//   DEPLOY_BLOCK          block the contract was deployed in (event history is read from here)
//   REPORTER_PRIVATE_KEY  the bot wallet's key (required off anvil; locally Anvil account 19 is used)

import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createPublicClient, createWalletClient, http, isAddressEqual } from 'viem'
import { mnemonicToAccount, privateKeyToAccount } from 'viem/accounts'
import { anvil, sepolia } from 'viem/chains'
import { SPORT_CODES, fetchEspnLeague } from '../server/espn.mjs'

const here = dirname(fileURLToPath(import.meta.url))
const abi = JSON.parse(readFileSync(resolve(here, '../src/abi/leagueTreasuryAbi.json'), 'utf8'))

const CHAINS = { anvil, sepolia }
const chain = CHAINS[process.env.CHAIN ?? 'anvil']
if (!chain) fail(`Unknown CHAIN "${process.env.CHAIN}". Use anvil or sepolia.`)
const isLocal = chain.id === anvil.id

const RPC_URL = process.env.RPC_URL || (isLocal ? 'http://127.0.0.1:8545' : undefined)
const ADDRESS = process.env.TREASURY_ADDRESS || (isLocal ? '0x5FbDB2315678afecb367f032d93F642f64180aa3' : undefined)
if (!ADDRESS) fail('Set TREASURY_ADDRESS to the deployed contract.')
const DEPLOY_BLOCK = BigInt(process.env.DEPLOY_BLOCK || '0')
const CHUNK_SIZE = 10_000n
const ACTIVE = 1 // LeagueState.ACTIVE
const ANVIL_MNEMONIC = 'test test test test test test test test test test test junk'

function fail(message) {
  console.error(`✗ ${message}`)
  process.exit(1)
}

function reporterAccount() {
  if (process.env.REPORTER_PRIVATE_KEY) return privateKeyToAccount(process.env.REPORTER_PRIVATE_KEY)
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

/** Contract events from the deploy block to now, a chunk of blocks at a time (public RPCs cap the range). */
async function scanEvents(eventName, eventArgs) {
  const latest = await publicClient.getBlockNumber()
  const events = []
  for (let fromBlock = DEPLOY_BLOCK; fromBlock <= latest; fromBlock += CHUNK_SIZE) {
    const end = fromBlock + CHUNK_SIZE - 1n
    const toBlock = end < latest ? end : latest
    events.push(...(await publicClient.getContractEvents({ ...contract, eventName, args: eventArgs, fromBlock, toBlock })))
  }
  return events
}

/** Posts one league's standings if it's in season and ESPN's season is final. Returns what happened. */
async function report(leagueId, created) {
  const { name, espnLeagueId, espnSeason, sport } = created.args
  const sportCode = SPORT_CODES[sport]
  console.log(`\nLeague ${leagueId}: ${name} (ESPN ${sportCode} ${espnSeason}, league ${espnLeagueId})`)

  const [, , teamCount, , state, reporter] = await publicClient.readContract({
    ...contract,
    functionName: 'leagues',
    args: [leagueId],
  })
  if (!isAddressEqual(reporter, account.address)) {
    throw new Error(`This bot signs as ${account.address}, but the league's reporter is ${reporter}.`)
  }
  if (state !== ACTIVE) return console.log('  Not in season (not full yet, or standings already posted). Skipped.')

  // Fresh from ESPN, never a cache: money follows this.
  const espn = await fetchEspnLeague(espnLeagueId, { sport: sportCode, season: espnSeason })
  if (!espn.isFinal && !testMode) {
    return console.log(`  Season isn't over (matchup ${espn.currentMatchupPeriod} of ${espn.finalMatchupPeriod}). Nothing posted.`)
  }
  if (!espn.isFinal) console.log('  --test: posting current standings, not final ones.')

  const joined = await scanEvents('MemberJoined', { leagueId })
  const joinedTeams = new Set(joined.map((log) => Number(log.args.teamId)))
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
const leagues = all
  ? await scanEvents('LeagueCreated', { reporter: account.address })
  : await scanEvents('LeagueCreated', { leagueId: BigInt(leagueArg) })
if (!all && leagues.length === 0) fail(`League ${leagueArg} doesn't exist.`)
if (all && leagues.length === 0) console.log('No leagues use this bot as their reporter yet.')

let failures = 0
for (const created of leagues) {
  try {
    await report(created.args.leagueId, created)
  } catch (err) {
    failures++
    console.error(`  ✗ ${err.shortMessage ?? err.message}`)
  }
}
process.exit(failures ? 1 : 0)
