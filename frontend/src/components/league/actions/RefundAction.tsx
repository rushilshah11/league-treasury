import { TxButton } from '@/components/TxButton'
import { leagueTreasury } from '@/config/contracts'
import { useTx } from '@/hooks/useTx'
import { formatUsdc } from '@/lib/format'
import { refundReason, type League, type Member } from '@/lib/league'
import { ActionCard } from '../ActionCard'

export function RefundAction({ league, me }: { league: League; me: Member }) {
  const tx = useTx()

  if (me.claimed) {
    return <ActionCard title="Refunded" description={`Your ${formatUsdc(league.buyIn)} buy-in was returned to your wallet.`} />
  }

  return (
    <ActionCard
      title="Get your buy-in back"
      description={`${refundReason(league)} You can withdraw your ${formatUsdc(league.buyIn)} buy-in.`}
    >
      <TxButton
        phase={tx.phase}
        error={tx.error}
        label="Withdraw refund"
        pendingLabel="Withdrawing…"
        onClick={() =>
          tx.run((write) => write({ ...leagueTreasury, functionName: 'withdrawRefund', args: [league.id] }))
        }
      />
    </ActionCard>
  )
}
