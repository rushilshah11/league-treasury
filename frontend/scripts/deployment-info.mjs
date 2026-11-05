// Prints the settings the app and the bot need after a deploy, read from
// Foundry's broadcast log. Usage: node scripts/deployment-info.mjs [chainId]
// (default 11155111, Ethereum Sepolia). From the repo root: make deployment-info
import { readFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const chainId = process.argv[2] ?? '11155111'
const here = dirname(fileURLToPath(import.meta.url))
const logPath = resolve(here, `../../broadcast/DeployLeagueTreasury.s.sol/${chainId}/run-latest.json`)

let run
try {
  run = JSON.parse(readFileSync(logPath, 'utf8'))
} catch {
  console.error(`No deploy found for chain ${chainId} (looked for ${logPath}). Run make deploy-sepolia first.`)
  process.exit(1)
}

const create = run.transactions.find((tx) => tx.transactionType === 'CREATE' && tx.contractName === 'LeagueTreasury')
const receipt = run.receipts.find((r) => r.transactionHash === create?.hash)
if (!create || !receipt) {
  console.error('The deploy log has no LeagueTreasury deployment.')
  process.exit(1)
}

const address = create.contractAddress
const block = Number(BigInt(receipt.blockNumber))
console.log(`LeagueTreasury: https://sepolia.etherscan.io/address/${address}\n`)
console.log('Frontend (frontend/.env.production and Netlify environment variables):')
console.log(`  VITE_CHAIN=sepolia`)
console.log(`  VITE_TREASURY_ADDRESS=${address}`)
console.log(`  VITE_DEPLOY_BLOCK=${block}`)
console.log('\nStandings bot (GitHub repo variables):')
console.log(`  TREASURY_ADDRESS=${address}`)
console.log(`  DEPLOY_BLOCK=${block}`)
