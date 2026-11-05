import type { Address } from 'viem'
import { leagueTreasuryAbi } from '../abi/leagueTreasuryAbi'
import { isLocalChain } from './chain'

// The first contract deployed by Anvil's account 0 on a fresh chain always lands
// at this address, so local development works without any configuration.
const ANVIL_FIRST_DEPLOYMENT: Address = '0x5FbDB2315678afecb367f032d93F642f64180aa3'

const configured = (import.meta.env.VITE_TREASURY_ADDRESS as Address | undefined) || undefined
if (!configured && !isLocalChain) {
  throw new Error('Set VITE_TREASURY_ADDRESS to the deployed contract (run `make deployment-info` after deploying).')
}

export const leagueTreasury = {
  address: configured ?? ANVIL_FIRST_DEPLOYMENT,
  abi: leagueTreasuryAbi,
} as const

/**
 * The block the contract was deployed in. Event history is read from here
 * instead of block 0, because public RPCs won't scan a whole testnet's history.
 */
export const DEPLOY_BLOCK = BigInt(import.meta.env.VITE_DEPLOY_BLOCK || '0')
