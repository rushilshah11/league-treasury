import { TxButton } from '@/components/TxButton'
import { leagueTreasury } from '@/config/contracts'
import { useTx } from '@/hooks/useTx'
import type { League } from '@/lib/league'
import { ActionCard } from '../ActionCard'

export function CancelAction({ league }: { league: League }) {
  const tx = useTx()
  return (
    <ActionCard
      title="Cancel league"
      description="Only possible before the league fills. Everyone who joined can then withdraw their buy-in."
    >
      <TxButton
        variant="outline"
        phase={tx.phase}
        error={tx.error}
        label="Cancel league"
        pendingLabel="Cancelling…"
        onClick={() =>
          tx.run((write) => write({ ...leagueTreasury, functionName: 'cancelLeague', args: [league.id] }))
        }
      />
    </ActionCard>
  )
}
