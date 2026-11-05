import { useAccount, useReadContract } from 'wagmi'
import { leagueTreasury } from '@/config/contracts'

/** IDs of the leagues the connected wallet is in, newest first. Commissioners are in their own leagues. */
export function useMyLeagues() {
  const { address } = useAccount()
  const query = useReadContract({
    ...leagueTreasury,
    functionName: 'getLeaguesOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address },
  })
  return { ...query, data: query.data ? [...query.data].reverse() : undefined }
}
