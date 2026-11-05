import type { PublicClient } from 'viem'
import { DEPLOY_BLOCK } from '@/config/contracts'

/** Most public RPCs cap how many blocks one log query may cover. */
const CHUNK_SIZE = BigInt(import.meta.env.VITE_LOG_CHUNK_SIZE || '10000')

/**
 * Reads contract events from the deploy block to now, a chunk of blocks at a time.
 * `query` is a getContractEvents call that receives each block range, e.g.
 *   scanEvents(client, (range) => client.getContractEvents({ ...leagueTreasury, eventName: 'MemberJoined', ...range }))
 */
export async function scanEvents<T>(
  client: PublicClient,
  query: (range: { fromBlock: bigint; toBlock: bigint }) => Promise<T[]>,
): Promise<T[]> {
  const latest = await client.getBlockNumber()
  const events: T[] = []
  for (let fromBlock = DEPLOY_BLOCK; fromBlock <= latest; fromBlock += CHUNK_SIZE) {
    const end = fromBlock + CHUNK_SIZE - 1n
    events.push(...(await query({ fromBlock, toBlock: end < latest ? end : latest })))
  }
  return events
}
