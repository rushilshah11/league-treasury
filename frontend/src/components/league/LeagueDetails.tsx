import { Stat, StatGrid } from '@/components/Stat'
import { seasonLabel } from '@/lib/espn'
import { shortAddress } from '@/lib/format'
import type { League } from '@/lib/league'

/** Who runs the league and where its standings come from. */
export function LeagueDetails({ league }: { league: League }) {
  return (
    <StatGrid>
      <Stat label="Commissioner" value={shortAddress(league.commissioner)} />
      <Stat label="Standings reporter" value={shortAddress(league.reporter)} />
      <Stat label="ESPN league" value={String(league.espn.leagueId)} />
      <Stat label="Season" value={seasonLabel(league.espn.sport, league.espn.season)} />
    </StatGrid>
  )
}
