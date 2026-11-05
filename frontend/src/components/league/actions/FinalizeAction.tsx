import { TxButton } from '@/components/TxButton'
import { leagueTreasury } from '@/config/contracts'
import { useTx } from '@/hooks/useTx'
import type { League } from '@/lib/league'
import { ActionCard } from '../ActionCard'

export function FinalizeAction({ league }: { league: League }) {
  const tx = useTx()
  return (
    <ActionCard
      title="Make the standings final"
      description="The dispute window closed with no disputes. Anyone can finalize the league so payouts open."
    >
      <TxButton
        phase={tx.phase}
        error={tx.error}
        label="Finalize league"
        pendingLabel="Finalizing…"
        onClick={() => tx.run((write) => write({ ...leagueTreasury, functionName: 'finalize', args: [league.id] }))}
      />
    </ActionCard>
  )
}
