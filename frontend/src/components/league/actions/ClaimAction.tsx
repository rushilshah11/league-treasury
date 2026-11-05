import { useAccount, useReadContract } from 'wagmi'
import { TxButton } from '@/components/TxButton'
import { leagueTreasury } from '@/config/contracts'
import { useTx } from '@/hooks/useTx'
import { formatEth } from '@/lib/format'
import type { League, Member } from '@/lib/league'
import { ActionCard } from '../ActionCard'

export function ClaimAction({ league, me }: { league: League; me: Member }) {
  const { address } = useAccount()
  const tx = useTx()
  const { data: payout } = useReadContract({
    ...leagueTreasury,
    functionName: 'getPayout',
    args: address ? [league.id, address] : undefined,
  })

  if (me.claimed) {
    return (
      <ActionCard
        title="You've been paid"
        description={`Your payout of ${payout !== undefined ? formatEth(payout) : 'your share'} was sent to your wallet.`}
      />
    )
  }

  return (
    <ActionCard
      title={`You finished #${me.finalPlace}`}
      description={payout !== undefined ? `Your payout is ${formatEth(payout)}.` : 'Loading your payout…'}
    >
      <TxButton
        phase={tx.phase}
        error={tx.error}
        label="Claim payout"
        pendingLabel="Claiming…"
        onClick={() => tx.run((write) => write({ ...leagueTreasury, functionName: 'claim', args: [league.id] }))}
      />
    </ActionCard>
  )
}
