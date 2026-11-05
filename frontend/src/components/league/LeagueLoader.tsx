import type { ReactNode } from 'react'
import { PageShell } from '@/components/PageShell'
import { PageStatus } from '@/components/PageStatus'
import { useLeague } from '@/hooks/useLeague'
import { useLeagueId } from '@/hooks/useLeagueId'
import type { League } from '@/lib/league'

/** Loads the league from the URL and handles the loading / not found states for its pages. */
export function LeagueLoader({
  children,
}: {
  children: (league: League, payoutBps: number[] | undefined) => ReactNode
}) {
  const leagueId = useLeagueId()
  const { league, payoutBps, isLoading, notFound, error } = useLeague(leagueId)

  if (leagueId === undefined || notFound) {
    return (
      <PageShell title="League not found">
        <PageStatus>There's no league at this link. Check the link with your commissioner.</PageStatus>
      </PageShell>
    )
  }
  if (error) {
    return (
      <PageShell title="League">
        <PageStatus>Couldn't reach the blockchain. Check your connection and refresh.</PageStatus>
      </PageShell>
    )
  }
  if (isLoading || !league) {
    return (
      <PageShell title="League">
        <PageStatus>Loading league…</PageStatus>
      </PageShell>
    )
  }
  return children(league, payoutBps)
}
