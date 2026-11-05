import { useAccount } from 'wagmi'
import { PageShell } from '@/components/PageShell'
import { Section } from '@/components/Section'
import { StatusBadge } from '@/components/StatusBadge'
import { LeagueActions } from '@/components/league/LeagueActions'
import { LeagueDetails } from '@/components/league/LeagueDetails'
import { LeagueLoader } from '@/components/league/LeagueLoader'
import { LeagueStats } from '@/components/league/LeagueStats'
import { LiveStandingsTable } from '@/components/league/LiveStandingsTable'
import { MembersTable } from '@/components/league/MembersTable'
import { PayoutTable } from '@/components/league/PayoutTable'
import { Text } from '@/components/typography'
import { useChainNow } from '@/hooks/useChainNow'
import { useEspnLeague } from '@/hooks/useEspnLeague'
import { useLeagueMembers } from '@/hooks/useLeagueMembers'
import { LeagueState, type League } from '@/lib/league'

function LeagueView({ league, payoutBps }: { league: League; payoutBps: number[] | undefined }) {
  const { address } = useAccount()
  const now = useChainNow()
  const { members } = useLeagueMembers(league.id)
  const espn = useEspnLeague(league.espn)
  const inSeason = league.state === LeagueState.Open || league.state === LeagueState.Active
  const posted = members.some((m) => m.finalPlace > 0)
  // ESPN's table already lists who joined, so the members table only shows once standings are posted.
  const showEspn = !!espn.data && !!payoutBps && (inSeason || (posted && league.state !== LeagueState.Finalized))
  const showMembers = posted || !espn.data

  return (
    <PageShell title={league.name || `League ${league.id}`} aside={<StatusBadge state={league.state} />}>
      <LeagueStats league={league} />
      <div className="flex flex-col gap-6">
        <LeagueActions league={league} members={members} me={address} now={now} />
      </div>
      {showEspn && (
        <Section title={inSeason ? 'Current standings' : 'Standings on ESPN'}>
          <Text variant="small">
            {inSeason
              ? `From ESPN, updated weekly. Payouts are projected for a full league; the money follows the final standings posted after the season.`
              : 'For checking the posted standings against ESPN.'}
          </Text>
          <LiveStandingsTable league={league} espn={espn.data!} members={members} payoutBps={payoutBps!} me={address} />
        </Section>
      )}
      {espn.error && (
        <Text variant="small">Couldn't load ESPN standings: {espn.error.message}</Text>
      )}
      {showMembers && (
        <Section title={posted ? 'Posted standings' : 'Members'}>
          <MembersTable league={league} members={members} payoutBps={payoutBps} me={address} />
        </Section>
      )}
      {inSeason && !showEspn && payoutBps && (
        <Section title="Payouts">
          <PayoutTable payoutBps={payoutBps} pot={league.buyIn * BigInt(league.teamCount)} />
        </Section>
      )}
      <Section title="Details">
        <LeagueDetails league={league} />
      </Section>
    </PageShell>
  )
}

export function LeaguePage() {
  return <LeagueLoader>{(league, payoutBps) => <LeagueView league={league} payoutBps={payoutBps} />}</LeagueLoader>
}

