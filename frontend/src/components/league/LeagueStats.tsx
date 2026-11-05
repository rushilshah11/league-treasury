import { Stat, StatGrid } from '@/components/Stat'
import { formatDateTime, formatEth } from '@/lib/format'
import { LeagueState, challengeWindowEnd, disputeResolutionEnd, pot, type League } from '@/lib/league'

/** The one date that matters most right now, for this league's stage. */
function keyDate(league: League): { label: string; value: number } | null {
  switch (league.state) {
    case LeagueState.Open:
      return { label: 'Join by', value: league.joinDeadline }
    case LeagueState.Active:
      return { label: 'Standings due by', value: league.standingsDeadline }
    case LeagueState.StandingsSubmitted:
      return { label: 'Disputes close', value: challengeWindowEnd(league) }
    case LeagueState.Disputed:
      return { label: 'Voting closes', value: disputeResolutionEnd(league) }
    default:
      return null
  }
}

export function LeagueStats({ league }: { league: League }) {
  const date = keyDate(league)
  return (
    <StatGrid>
      <Stat label="Pot" value={formatEth(pot(league))} />
      <Stat label="Buy-in" value={formatEth(league.buyIn)} />
      <Stat label="Teams" value={`${league.memberCount} of ${league.teamCount}`} />
      {date && <Stat label={date.label} value={formatDateTime(date.value)} />}
    </StatGrid>
  )
}
