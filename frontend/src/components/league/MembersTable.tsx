import { isAddressEqual, type Address } from 'viem'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Text } from '@/components/typography'
import { useTeamNames } from '@/hooks/useEspnLeague'
import { teamLabel } from '@/lib/espn'
import { formatUsdc, shortAddress } from '@/lib/format'
import { LeagueState, pot, type League, type Member } from '@/lib/league'
import { payoutAmounts } from '@/lib/payouts'

type MembersTableProps = {
  league: League
  members: Member[]
  payoutBps: number[] | undefined
  me: Address | undefined
}

/** Who's in the league; once standings are posted, where they finished and what they get. */
export function MembersTable({ league, members, payoutBps, me }: MembersTableProps) {
  const names = useTeamNames(league.espn)
  if (members.length === 0) {
    return <Text variant="muted">No one has joined yet. Share the invite link to get started.</Text>
  }

  const ranked = members.some((m) => m.finalPlace > 0)
  const amounts = payoutBps ? payoutAmounts(pot(league), payoutBps) : []
  const settled = league.state === LeagueState.Finalized

  return (
    <Table>
      <TableHeader>
        <TableRow>
          {ranked && <TableHead>Place</TableHead>}
          <TableHead>Team</TableHead>
          <TableHead>Member</TableHead>
          {ranked && <TableHead className="text-right">Payout</TableHead>}
          {settled && <TableHead className="text-right">Status</TableHead>}
        </TableRow>
      </TableHeader>
      <TableBody>
        {members.map((member) => {
          const isMe = !!me && isAddressEqual(member.address, me)
          return (
            <TableRow key={member.address}>
              {ranked && <TableCell className="font-bold">{member.finalPlace || '–'}</TableCell>}
              <TableCell>{teamLabel(names, member.teamId)}</TableCell>
              <TableCell>
                {shortAddress(member.address)}
                {isMe && <span className="ml-2 font-bold text-primary">You</span>}
              </TableCell>
              {ranked && (
                <TableCell className="text-right">
                  {member.finalPlace ? formatUsdc(amounts[member.finalPlace - 1] ?? 0n) : '–'}
                </TableCell>
              )}
              {settled && (
                <TableCell className="text-right text-muted-foreground">
                  {member.claimed ? 'Paid' : 'Unclaimed'}
                </TableCell>
              )}
            </TableRow>
          )
        })}
      </TableBody>
    </Table>
  )
}
