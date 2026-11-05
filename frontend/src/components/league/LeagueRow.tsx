import { Link } from 'react-router-dom'
import { isAddressEqual, type Address } from 'viem'
import { StatusBadge } from '@/components/StatusBadge'
import { TableCell, TableRow } from '@/components/ui/table'
import { useLeague } from '@/hooks/useLeague'
import { formatEth } from '@/lib/format'
import { pot } from '@/lib/league'

/** One league in the "My leagues" list. */
export function LeagueRow({ leagueId, me }: { leagueId: bigint; me: Address }) {
  const { league } = useLeague(leagueId)
  if (!league) return null
  const role = isAddressEqual(league.commissioner, me) ? 'Commissioner' : 'Member'
  return (
    <TableRow>
      <TableCell className="font-bold">
        <Link to={`/league/${league.id}`} className="hover:text-primary">
          {league.name || `League ${league.id}`}
        </Link>
      </TableCell>
      <TableCell className="text-muted-foreground">{role}</TableCell>
      <TableCell>
        {league.memberCount} of {league.teamCount}
      </TableCell>
      <TableCell>{formatEth(pot(league))}</TableCell>
      <TableCell className="text-right">
        <StatusBadge state={league.state} />
      </TableCell>
    </TableRow>
  )
}
