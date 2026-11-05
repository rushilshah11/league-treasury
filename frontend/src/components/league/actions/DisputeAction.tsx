import { TxButton } from '@/components/TxButton'
import { leagueTreasury } from '@/config/contracts'
import { useTx } from '@/hooks/useTx'
import { formatDuration } from '@/lib/format'
import { challengeWindowEnd, type League } from '@/lib/league'
import { ActionCard } from '../ActionCard'

export function DisputeAction({ league, now }: { league: League; now: number }) {
  const tx = useTx()
  return (
    <ActionCard
      title="Check the standings"
      description={`If these standings don't match ESPN, dispute them. Members then vote on corrected standings, and a majority makes them final. ${formatDuration(challengeWindowEnd(league) - now)} left to dispute.`}
    >
      <TxButton
        variant="outline"
        phase={tx.phase}
        error={tx.error}
        label="Dispute standings"
        pendingLabel="Disputing…"
        onClick={() => tx.run((write) => write({ ...leagueTreasury, functionName: 'dispute', args: [league.id] }))}
      />
    </ActionCard>
  )
}
