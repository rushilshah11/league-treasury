import { useAccount } from 'wagmi'
import { ButtonLink } from '@/components/ButtonLink'
import { ConnectPrompt } from '@/components/ConnectPrompt'
import { PageShell } from '@/components/PageShell'
import { PageStatus } from '@/components/PageStatus'
import { LeagueRow } from '@/components/league/LeagueRow'
import { Table, TableBody, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { useMyLeagues } from '@/hooks/useMyLeagues'

export function MyLeagues() {
  const { address } = useAccount()
  const { data: leagues, isLoading } = useMyLeagues()
  const create = (
    <ButtonLink to="/create" size="lg">
      Create a league
    </ButtonLink>
  )

  let body
  if (!address) body = <ConnectPrompt>Connect your wallet to see the leagues you run or play in.</ConnectPrompt>
  else if (isLoading) body = <PageStatus>Loading your leagues…</PageStatus>
  else if (!leagues?.length)
    body = (
      <div className="flex flex-col items-start gap-6">
        <PageStatus>You're not in any leagues yet. Create one, or open an invite link from your commissioner.</PageStatus>
        {create}
      </div>
    )
  else
    body = (
      <>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>League</TableHead>
              <TableHead>Your role</TableHead>
              <TableHead>Teams</TableHead>
              <TableHead>Pot</TableHead>
              <TableHead className="text-right">Status</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {leagues.map((id) => (
              <LeagueRow key={id.toString()} leagueId={id} me={address} />
            ))}
          </TableBody>
        </Table>
        <div>{create}</div>
      </>
    )

  return <PageShell title="My leagues">{body}</PageShell>
}
