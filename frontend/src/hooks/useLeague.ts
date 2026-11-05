import { useReadContract } from 'wagmi'
import { leagueTreasury } from '@/config/contracts'
import { SPORTS } from '@/lib/espn'
import type { League, LeagueState } from '@/lib/league'

/** Everything about one league, read straight from contract storage. */
export function useLeague(leagueId: bigint | undefined) {
  const enabled = leagueId !== undefined
  const args = enabled ? ([leagueId] as const) : undefined

  // League IDs count up from 0, so any ID below nextLeagueId exists.
  const count = useReadContract({ ...leagueTreasury, functionName: 'nextLeagueId' })
  const exists = enabled && count.data !== undefined && leagueId < count.data

  const stored = useReadContract({ ...leagueTreasury, functionName: 'leagues', args, query: { enabled: exists } })
  const info = useReadContract({ ...leagueTreasury, functionName: 'getLeagueInfo', args, query: { enabled: exists } })
  const payout = useReadContract({ ...leagueTreasury, functionName: 'getPayoutBps', args, query: { enabled: exists } })

  let league: League | undefined
  if (exists && stored.data && info.data) {
    const [
      commissioner,
      joinDeadline,
      teamCount,
      memberCount,
      state,
      reporter,
      standingsDeadline,
      buyIn,
      standingsSubmittedAt,
      disputedAt,
    ] = stored.data
    const [name, espn] = info.data
    league = {
      id: leagueId,
      name,
      espn: {
        leagueId: Number(espn.leagueId),
        season: espn.season,
        sport: SPORTS[espn.sport]?.code ?? 'fba',
      },
      commissioner,
      reporter,
      buyIn,
      teamCount,
      memberCount,
      state: state as LeagueState,
      joinDeadline: Number(joinDeadline),
      standingsDeadline: Number(standingsDeadline),
      standingsSubmittedAt: Number(standingsSubmittedAt),
      disputedAt: Number(disputedAt),
    }
  }

  return {
    league,
    payoutBps: payout.data?.map(Number),
    isLoading: count.isLoading || stored.isLoading || info.isLoading,
    notFound: enabled && count.data !== undefined && !exists,
    error: count.error ?? stored.error ?? info.error,
  }
}
