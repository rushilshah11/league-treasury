import { ButtonLink } from '@/components/ButtonLink'
import { CopyField } from '@/components/CopyField'
import { Text } from '@/components/typography'
import { inviteLink } from '@/components/league/actions/InviteAction'

export function LeagueCreated({ leagueId }: { leagueId: bigint }) {
  return (
    <div className="flex flex-col gap-8">
      <Text variant="lead" measure="readable">
        Your league is live and you're in it. Send this link to your league so everyone can join and pay their buy-in.
      </Text>
      <CopyField id="invite-link" label="Invite link" value={inviteLink(leagueId)} />
      <div className="flex flex-wrap gap-4">
        <ButtonLink to={`/league/${leagueId}`} size="lg">
          Go to league
        </ButtonLink>
      </div>
    </div>
  )
}
