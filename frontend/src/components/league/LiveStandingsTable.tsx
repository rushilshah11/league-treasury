import { isAddressEqual, type Address } from 'viem'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { formatEth, shortAddress } from '@/lib/format'
import { formatRecord, type EspnLeague } from '@/lib/espn'
import type { League, Member } from '@/lib/league'
import { formatBps, payoutAmounts } from '@/lib/payouts'

type LiveStandingsTableProps = {
  league: League
  espn: EspnLeague
  members: Member[]
  payoutBps: number[]
  me: Address | undefined
}

/**
 * ESPN's current standings with what each place would pay if the season ended
 * today. Projected from a full league's pot; the money follows only the final
 * standings the reporter posts.
 */
export function LiveStandingsTable({ league, espn, members, payoutBps, me }: LiveStandingsTableProps) {
  const fullPot = league.buyIn * BigInt(league.teamCount)
  const amounts = payoutAmounts(fullPot, payoutBps)
  const ownerOf = new Map(members.map((m) => [m.teamId, m.address]))

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Rank</TableHead>
          <TableHead>Team</TableHead>
          <TableHead>Record</TableHead>
          <TableHead>Member</TableHead>
          <TableHead className="text-right">Share</TableHead>
          <TableHead className="text-right">Payout</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {espn.teams.map((team, i) => {
          const owner = ownerOf.get(team.id)
          const isMe = !!owner && !!me && isAddressEqual(owner, me)
          return (
            <TableRow key={team.id}>
              <TableCell className="font-bold">{team.rank}</TableCell>
              <TableCell>{team.name}</TableCell>
              <TableCell>{formatRecord(team)}</TableCell>
              <TableCell className={owner ? undefined : 'text-muted-foreground'}>
                {owner ? shortAddress(owner) : 'Not joined'}
                {isMe && <span className="ml-2 font-bold text-primary">You</span>}
              </TableCell>
              <TableCell className="text-right">{payoutBps[i] !== undefined ? formatBps(payoutBps[i]) : '–'}</TableCell>
              <TableCell className="text-right">{amounts[i] !== undefined ? formatEth(amounts[i]) : '–'}</TableCell>
            </TableRow>
          )
        })}
      </TableBody>
    </Table>
  )
}
