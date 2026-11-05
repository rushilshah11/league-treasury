import { isAddressEqual } from 'viem'
import { useAccount } from 'wagmi'
import { useNavigate } from 'react-router-dom'
import { ButtonLink } from '@/components/ButtonLink'
import { ConnectPrompt } from '@/components/ConnectPrompt'
import { PageShell } from '@/components/PageShell'
import { PageStatus } from '@/components/PageStatus'
import { StatusBadge } from '@/components/StatusBadge'
import { Text } from '@/components/typography'
import { JoinForm } from '@/components/league/JoinForm'
import { LeagueLoader } from '@/components/league/LeagueLoader'
import { LeagueStats } from '@/components/league/LeagueStats'
import { useChainNow } from '@/hooks/useChainNow'
import { useLeagueMembers } from '@/hooks/useLeagueMembers'
import { LeagueState, type League } from '@/lib/league'

function JoinView({ league }: { league: League }) {
  const { address } = useAccount()
  const now = useChainNow()
  const navigate = useNavigate()
  const { members, isLoading } = useLeagueMembers(league.id)
  const leaguePath = `/league/${league.id}`

  const isMember = !!address && members.some((m) => isAddressEqual(m.address, address))
  const isReporter = !!address && isAddressEqual(league.reporter, address)
  const isOpen = league.state === LeagueState.Open && now < league.joinDeadline

  let body
  if (isMember) {
    body = (
      <div className="flex flex-col items-start gap-6">
        <PageStatus>You're in this league.</PageStatus>
        <ButtonLink to={leaguePath} size="lg">
          Go to league
        </ButtonLink>
      </div>
    )
  } else if (isReporter) {
    body = <PageStatus>You're this league's standings reporter, so you can't have a team in it.</PageStatus>
  } else if (!isOpen) {
    body = (
      <div className="flex flex-col items-start gap-6">
        <PageStatus>This league isn't taking new members anymore.</PageStatus>
        <ButtonLink to={leaguePath} size="lg" variant="outline">
          View league
        </ButtonLink>
      </div>
    )
  } else if (!address) {
    body = <ConnectPrompt>Connect your wallet to join. Your buy-in is held by the contract, not the commissioner.</ConnectPrompt>
  } else if (isLoading) {
    body = <PageStatus>Loading members…</PageStatus>
  } else {
    body = <JoinForm league={league} members={members} onJoined={() => navigate(leaguePath)} />
  }

  return (
    <PageShell title={`Join ${league.name || `league ${league.id}`}`} aside={<StatusBadge state={league.state} />}>
      <Text variant="lead" measure="readable">
        Your buy-in goes into the league's contract. It pays out automatically by final standings, or comes back to you if the season falls through.
      </Text>
      <LeagueStats league={league} />
      {body}
    </PageShell>
  )
}

export function JoinLeague() {
  return <LeagueLoader>{(league) => <JoinView league={league} />}</LeagueLoader>
}
