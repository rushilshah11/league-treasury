import { useQuery } from '@tanstack/react-query'
import { usePublicClient, useReadContracts } from 'wagmi'
import type { Address } from 'viem'
import { leagueTreasury } from '@/config/contracts'
import { scanEvents } from '@/lib/logs'
import type { Member } from '@/lib/league'

/**
 * Members of a league. The contract can't list a mapping, so we find members
 * from MemberJoined events, then read each one's current record.
 */
export function useLeagueMembers(leagueId: bigint | undefined) {
  const client = usePublicClient()

  const joined = useQuery({
    queryKey: ['MemberJoined', leagueId?.toString()],
    enabled: leagueId !== undefined && !!client,
    queryFn: async () => {
      const logs = await scanEvents(client!, (range) =>
        client!.getContractEvents({ ...leagueTreasury, eventName: 'MemberJoined', args: { leagueId }, ...range }),
      )
      return logs.map((log) => log.args.member as Address)
    },
  })

  const addresses = joined.data ?? []
  const records = useReadContracts({
    contracts: addresses.map((address) => ({
      ...leagueTreasury,
      functionName: 'members' as const,
      args: [leagueId!, address] as const,
    })),
    query: { enabled: addresses.length > 0 },
  })

  const members: Member[] = addresses.flatMap((address, i) => {
    const result = records.data?.[i]?.result
    if (!result) return []
    const [teamId, , claimed, finalPlace] = result
    return [{ address, teamId, claimed, finalPlace }]
  })

  // Ranked members first (by finishing place), then everyone else by team id.
  members.sort((a, b) => {
    if (a.finalPlace && b.finalPlace) return a.finalPlace - b.finalPlace
    if (a.finalPlace) return -1
    if (b.finalPlace) return 1
    return a.teamId - b.teamId
  })

  return { members, isLoading: joined.isLoading || records.isLoading }
}
