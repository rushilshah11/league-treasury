import { useReadContract } from 'wagmi'
import { leagueTreasury } from '@/config/contracts'
import type { Member } from '@/lib/league'

/** Every member of a league with their record, in one contract call. */
export function useLeagueMembers(leagueId: bigint | undefined) {
  const { data, isLoading } = useReadContract({
    ...leagueTreasury,
    functionName: 'getMembers',
    args: leagueId !== undefined ? [leagueId] : undefined,
    query: { enabled: leagueId !== undefined },
  })

  const [addresses = [], records = []] = data ?? []
  const members: Member[] = addresses.map((address, i) => ({
    address,
    teamId: records[i].teamId,
    claimed: records[i].claimed,
    finalPlace: records[i].finalPlace,
  }))

  // Ranked members first (by finishing place), then everyone else by team id.
  members.sort((a, b) => {
    if (a.finalPlace && b.finalPlace) return a.finalPlace - b.finalPlace
    if (a.finalPlace) return -1
    if (b.finalPlace) return 1
    return a.teamId - b.teamId
  })

  return { members, isLoading }
}
