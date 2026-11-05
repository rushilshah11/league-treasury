import { useQuery } from '@tanstack/react-query'
import { useAccount, usePublicClient } from 'wagmi'
import { leagueTreasury } from '@/config/contracts'

export type MyLeague = { id: bigint; isCommissioner: boolean; isMember: boolean }

/**
 * Leagues the connected wallet runs or has joined, found through the indexed
 * `commissioner` and `member` fields in the contract's events.
 */
export function useMyLeagues() {
  const { address } = useAccount()
  const client = usePublicClient()

  return useQuery({
    queryKey: ['myLeagues', address],
    enabled: !!address && !!client,
    queryFn: async (): Promise<MyLeague[]> => {
      const [created, joined] = await Promise.all([
        client!.getContractEvents({
          ...leagueTreasury,
          eventName: 'LeagueCreated',
          args: { commissioner: address },
          fromBlock: 0n,
        }),
        client!.getContractEvents({
          ...leagueTreasury,
          eventName: 'MemberJoined',
          args: { member: address },
          fromBlock: 0n,
        }),
      ])

      const byId = new Map<bigint, MyLeague>()
      const entry = (id: bigint) => {
        if (!byId.has(id)) byId.set(id, { id, isCommissioner: false, isMember: false })
        return byId.get(id)!
      }
      created.forEach((log) => (entry(log.args.leagueId!).isCommissioner = true))
      joined.forEach((log) => (entry(log.args.leagueId!).isMember = true))

      return [...byId.values()].sort((a, b) => (a.id > b.id ? -1 : 1))
    },
  })
}
