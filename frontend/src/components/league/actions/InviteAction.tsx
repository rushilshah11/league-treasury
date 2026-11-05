import { CopyField } from '@/components/CopyField'
import { ButtonLink } from '@/components/ButtonLink'
import { formatDateTime } from '@/lib/format'
import type { League } from '@/lib/league'
import { ActionCard } from '../ActionCard'

export function inviteLink(leagueId: bigint): string {
  return `${window.location.origin}/league/${leagueId}/join`
}

export function InviteAction({ league, canJoin }: { league: League; canJoin: boolean }) {
  const spotsLeft = league.teamCount - league.memberCount
  return (
    <ActionCard
      title={`${spotsLeft} ${spotsLeft === 1 ? 'spot' : 'spots'} left`}
      description={`Share the invite link with your league. Joining closes ${formatDateTime(league.joinDeadline)}.`}
    >
      <CopyField id="invite-link" label="Invite link" value={inviteLink(league.id)} />
      {canJoin && (
        <div>
          <ButtonLink to={`/league/${league.id}/join`} size="lg">
            Join this league
          </ButtonLink>
        </div>
      )}
    </ActionCard>
  )
}
