import { leagueTreasury } from '@/config/contracts'
import { useTx } from '@/hooks/useTx'
import { formatDateTime } from '@/lib/format'
import { disputeResolutionEnd, type League, type Member } from '@/lib/league'
import { ActionCard } from '../ActionCard'
import { RankingForm } from '../RankingForm'

export function ResolveDisputeAction({ league, members }: { league: League; members: Member[] }) {
  const tx = useTx()
  return (
    <ActionCard
      title="Resolve the dispute"
      description={`Post the correct standings. They're final once posted. If you don't resolve this by ${formatDateTime(disputeResolutionEnd(league))}, members can withdraw their buy-ins instead.`}
    >
      <RankingForm
        id="corrected-standings"
        members={members}
        phase={tx.phase}
        error={tx.error}
        label="Post corrected standings"
        pendingLabel="Posting…"
        onSubmit={(ranking) =>
          tx.run((write) =>
            write({ ...leagueTreasury, functionName: 'resolveDispute', args: [league.id, ranking] }),
          )
        }
      />
    </ActionCard>
  )
}
