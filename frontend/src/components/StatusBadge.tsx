import { Badge } from '@/components/ui/badge'
import { LeagueState, STATE_LABELS } from '@/lib/league'

const VARIANT: Record<LeagueState, 'default' | 'outline' | 'destructive' | 'muted'> = {
  [LeagueState.Open]: 'outline',
  [LeagueState.Active]: 'outline',
  [LeagueState.StandingsSubmitted]: 'default',
  [LeagueState.Disputed]: 'destructive',
  [LeagueState.Finalized]: 'default',
  [LeagueState.Cancelled]: 'muted',
}

export function StatusBadge({ state }: { state: LeagueState }) {
  return <Badge variant={VARIANT[state]}>{STATE_LABELS[state]}</Badge>
}
