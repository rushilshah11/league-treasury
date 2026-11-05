import { useQuery } from '@tanstack/react-query'
import { usePublicClient, useReadContract } from 'wagmi'
import { leagueTreasury } from '@/config/contracts'
import { SPORTS } from '@/lib/espn'
import type { League, LeagueState } from '@/lib/league'

/**
 * Everything about one league: its stored fields, plus the name and ESPN id,
 * which only live in the LeagueCreated event (cheaper than storage).
 */
export function useLeague(leagueId: bigint | undefined) {
  const client = usePublicClient()
  const enabled = leagueId !== undefined

  const stored = useReadContract({
    ...leagueTreasury,
    functionName: 'leagues',
    args: enabled ? [leagueId] : undefined,
    query: { enabled },
  })

  const payout = useReadContract({
    ...leagueTreasury,
    functionName: 'getPayoutBps',
    args: enabled ? [leagueId] : undefined,
    query: { enabled },
  })

  const created = useQuery({
    queryKey: ['LeagueCreated', leagueId?.toString()],
    enabled: enabled && !!client,
    queryFn: async () => {
      const [log] = await client!.getContractEvents({
        ...leagueTreasury,
        eventName: 'LeagueCreated',
        args: { leagueId },
        fromBlock: 0n,
      })
      return log?.args ?? null
    },
  })

  const exists = created.data !== null && created.data !== undefined
  let league: League | undefined
  if (enabled && stored.data && exists) {
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
    league = {
      id: leagueId,
      name: created.data?.name ?? '',
      espn: {
        leagueId: Number(created.data?.espnLeagueId ?? 0n),
        season: created.data?.espnSeason ?? 0,
        sport: SPORTS[created.data?.sport ?? 1]?.code ?? 'fba',
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
    isLoading: stored.isLoading || created.isLoading,
    notFound: enabled && created.isSuccess && !exists,
    error: stored.error ?? created.error,
  }
}
