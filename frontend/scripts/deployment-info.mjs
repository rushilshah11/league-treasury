// Prints the settings the app and the bot need after a deploy, read from
// Foundry's broadcast log. Usage: node scripts/deployment-info.mjs [chainId]
// (default 11155111, Ethereum Sepolia; 84532 for Base Sepolia). From the repo root: make deployment-info
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const chainId = process.argv[2] ?? '11155111'
const NETWORKS = {
  11155111: { name: 'sepolia', explorer: 'https://sepolia.etherscan.io', make: 'deploy-sepolia' },
  84532: { name: 'base-sepolia', explorer: 'https://sepolia.basescan.org', make: 'deploy-base-sepolia' },
}
const network = NETWORKS[chainId]
if (!network) {
  console.error(`Unknown chain id ${chainId}. Use 11155111 (Ethereum Sepolia) or 84532 (Base Sepolia).`)
  process.exit(1)
}
const here = dirname(fileURLToPath(import.meta.url))
const logPath = resolve(here, `../../broadcast/DeployLeagueTreasury.s.sol/${chainId}/run-latest.json`)

let run
try {
  run = JSON.parse(readFileSync(logPath, 'utf8'))
} catch {
  console.error(`No deploy found for chain ${chainId} (looked for ${logPath}). Run make ${network.make} first.`)
  process.exit(1)
}

const create = run.transactions.find((tx) => tx.transactionType === 'CREATE' && tx.contractName === 'LeagueTreasury')
const receipt = run.receipts.find((r) => r.transactionHash === create?.hash)
if (!create || !receipt) {
  console.error('The deploy log has no LeagueTreasury deployment.')
  process.exit(1)
}

const address = create.contractAddress
console.log(`LeagueTreasury: ${network.explorer}/address/${address}`)
console.log(`Deployed in block ${Number(BigInt(receipt.blockNumber))}\n`)
console.log('Vercel environment variables:')
console.log(`  VITE_CHAIN=${network.name}`)
console.log(`  VITE_TREASURY_ADDRESS=${address}`)
console.log('\nStandings bot (GitHub repo variable):')
console.log(`  TREASURY_ADDRESS=${address}`)
