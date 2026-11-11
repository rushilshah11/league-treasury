import type { Address } from 'viem'
import { leagueTreasuryAbi } from '../abi/leagueTreasuryAbi'
import { isLocalChain } from './chain'

// Contract addresses come from the deployer's address plus its nonce, so on a fresh
// Anvil chain they're fixed by deploy order. The deploy script deploys MockUSDC first
// (nonce 0 → 0x5FbD…0aa3) and the treasury second (nonce 1 → this address), so local
// development works without any configuration. Reordering the script changes this.
const ANVIL_TREASURY_DEPLOYMENT: Address = '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512'

const configured = (import.meta.env.VITE_TREASURY_ADDRESS as Address | undefined) || undefined
if (!configured && !isLocalChain) {
  throw new Error('Set VITE_TREASURY_ADDRESS to the deployed contract (`make deployment-info` prints it).')
}

export const leagueTreasury = {
  address: configured ?? ANVIL_TREASURY_DEPLOYMENT,
  abi: leagueTreasuryAbi,
} as const
