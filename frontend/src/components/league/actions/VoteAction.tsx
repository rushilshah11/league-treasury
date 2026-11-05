import type { Address } from 'viem'
import { leagueTreasury } from '@/config/contracts'
import { useProposals } from '@/hooks/useProposals'
import { useTx } from '@/hooks/useTx'
import { formatDateTime } from '@/lib/format'
import { disputeResolutionEnd, majority, type League, type Member } from '@/lib/league'
import { ActionCard } from '../ActionCard'
import { ProposalCard } from '../ProposalCard'
import { RankingForm } from '../RankingForm'

/**
 * Shown to members while standings are disputed. Any member can propose
 * corrected standings; they become final once a majority votes for them.
 */
export function VoteAction({ league, members, me }: { league: League; members: Member[]; me: Address | undefined }) {
  const { proposals } = useProposals(league.id, me)
  const tx = useTx()
  const needed = majority(league)

  return (
    <>
      <ActionCard
        title="Vote on the standings"
        description={`The posted standings were disputed. Vote for the correct standings, or propose them if no one has yet. ${needed} of ${league.memberCount} votes make them final. Voting closes ${formatDateTime(disputeResolutionEnd(league))}; if no standings win by then, everyone can withdraw their buy-in.`}
      >
        {proposals.map((proposal) => (
          <ProposalCard key={proposal.id.toString()} league={league} proposal={proposal} needed={needed} me={me} />
        ))}
      </ActionCard>
      <ActionCard
        title="Propose standings"
        description="Starts with the posted standings. Your proposal counts as your vote."
      >
        <RankingForm
          id="proposed-standings"
          members={members}
          phase={tx.phase}
          error={tx.error}
          label="Propose standings"
          pendingLabel="Proposing…"
          onSubmit={(ranking) =>
            tx.run((write) =>
              write({ ...leagueTreasury, functionName: 'proposeStandings', args: [league.id, ranking] }),
            )
          }
        />
      </ActionCard>
    </>
  )
}
