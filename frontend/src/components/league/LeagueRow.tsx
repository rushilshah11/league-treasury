import { Link } from 'react-router-dom'
import { StatusBadge } from '@/components/StatusBadge'
import { TableCell, TableRow } from '@/components/ui/table'
import { useLeague } from '@/hooks/useLeague'
import { formatEth } from '@/lib/format'
import { pot } from '@/lib/league'
import type { MyLeague } from '@/hooks/useMyLeagues'

function role({ isCommissioner, isMember }: MyLeague): string {
  if (isCommissioner && isMember) return 'Commissioner, member'
  return isCommissioner ? 'Commissioner' : 'Member'
}

/** One league in the "My leagues" list. */
export function LeagueRow({ entry }: { entry: MyLeague }) {
  const { league } = useLeague(entry.id)
  if (!league) return null
  return (
    <TableRow>
      <TableCell className="font-bold">
        <Link to={`/league/${league.id}`} className="hover:text-primary">
          {league.name || `League ${league.id}`}
        </Link>
      </TableCell>
      <TableCell className="text-muted-foreground">{role(entry)}</TableCell>
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
