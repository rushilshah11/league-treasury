import { isAddressEqual, type Address } from 'viem'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { TxButton } from '@/components/TxButton'
import { Text } from '@/components/typography'
import { leagueTreasury } from '@/config/contracts'
import { useTeamNames } from '@/hooks/useEspnLeague'
import type { StandingsProposal } from '@/hooks/useProposals'
import { teamLabel } from '@/lib/espn'
import { useTx } from '@/hooks/useTx'
import { shortAddress } from '@/lib/format'
import type { League } from '@/lib/league'

type ProposalCardProps = {
  league: League
  proposal: StandingsProposal
  needed: number
  me: Address | undefined
}

/** One proposed set of corrected standings, its vote count, and an approve button. */
export function ProposalCard({ league, proposal, needed, me }: ProposalCardProps) {
  const tx = useTx()
  const names = useTeamNames(league.espn)
  const proposedByMe = !!me && isAddressEqual(proposal.proposer, me)

  return (
    <Card className="gap-4">
      <CardHeader>
        <CardTitle>
          {proposal.approvals} of {needed} votes
        </CardTitle>
        <CardDescription>
          Proposed by {proposedByMe ? 'you' : shortAddress(proposal.proposer)}
        </CardDescription>
      </CardHeader>
      <ol className="flex flex-wrap gap-x-5 gap-y-1 text-body">
        {proposal.rankedTeamIds.map((teamId, i) => (
          <li key={teamId}>
            <span className="text-muted-foreground">{i + 1}.</span> {teamLabel(names, teamId)}
          </li>
        ))}
      </ol>
      {proposal.approvedByMe ? (
        <Text variant="small">You voted for these standings.</Text>
      ) : (
        <TxButton
          variant="outline"
          phase={tx.phase}
          error={tx.error}
          label="Vote for these standings"
          pendingLabel="Voting…"
          onClick={() =>
            tx.run((write) =>
              write({ ...leagueTreasury, functionName: 'approveProposal', args: [league.id, proposal.id] }),
            )
          }
        />
      )}
    </Card>
  )
}
