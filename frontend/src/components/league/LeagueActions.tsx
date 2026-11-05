import { isAddressEqual, type Address } from 'viem'
import { formatDateTime } from '@/lib/format'
import {
  LeagueState,
  challengeWindowEnd,
  disputeResolutionEnd,
  isRefundable,
  type League,
  type Member,
} from '@/lib/league'
import { CancelAction } from './actions/CancelAction'
import { ClaimAction } from './actions/ClaimAction'
import { DisputeAction } from './actions/DisputeAction'
import { FinalizeAction } from './actions/FinalizeAction'
import { InviteAction } from './actions/InviteAction'
import { RefundAction } from './actions/RefundAction'
import { SubmitStandingsAction } from './actions/SubmitStandingsAction'
import { VoteAction } from './actions/VoteAction'
import { WaitingAction } from './actions/WaitingAction'

type LeagueActionsProps = {
  league: League
  members: Member[]
  me: Address | undefined
  now: number
}

/**
 * Picks what the viewer can do right now, from the league's state, the time,
 * and the viewer's role. This mirrors the contract's rules so buttons only
 * appear when the transaction would succeed.
 */
export function LeagueActions({ league, members, me, now }: LeagueActionsProps) {
  const is = (address: Address) => !!me && isAddressEqual(address, me)
  const isCommissioner = is(league.commissioner)
  const isReporter = is(league.reporter)
  const myMembership = members.find((m) => is(m.address))

  if (myMembership && isRefundable(league, now)) {
    return <RefundAction league={league} me={myMembership} />
  }

  switch (league.state) {
    case LeagueState.Open: {
      const joinOpen = now < league.joinDeadline
      return (
        <>
          {joinOpen && <InviteAction league={league} canJoin={!myMembership && !!me && !isReporter} />}
          {!joinOpen && (
            <WaitingAction
              title="Joining has closed"
              description="The league didn't fill before the join deadline. Members can withdraw their buy-ins."
            />
          )}
          {isCommissioner && joinOpen && <CancelAction league={league} />}
        </>
      )
    }

    case LeagueState.Active:
      if (isReporter && now < league.standingsDeadline) {
        return <SubmitStandingsAction league={league} members={members} />
      }
      return (
        <WaitingAction
          title="Season in progress"
          description={`The league is full and the money is locked in. Final standings are due by ${formatDateTime(league.standingsDeadline)}.`}
        />
      )

    case LeagueState.StandingsSubmitted:
      if (now >= challengeWindowEnd(league)) return <FinalizeAction league={league} />
      if (myMembership) return <DisputeAction league={league} now={now} />
      return (
        <WaitingAction
          title="Standings posted"
          description={`Members have until ${formatDateTime(challengeWindowEnd(league))} to dispute them.`}
        />
      )

    case LeagueState.Disputed:
      if (myMembership && now < disputeResolutionEnd(league)) {
        return <VoteAction league={league} members={members} me={me} />
      }
      return (
        <WaitingAction
          title="Standings disputed"
          description={`Members are voting on corrected standings until ${formatDateTime(disputeResolutionEnd(league))}.`}
        />
      )

    case LeagueState.Finalized:
      if (myMembership) return <ClaimAction league={league} me={myMembership} />
      return <WaitingAction title="League final" description="Standings are final and members are claiming their payouts." />

    case LeagueState.Cancelled:
      return <WaitingAction title="League cancelled" description="Members can withdraw their buy-ins." />
  }
}
