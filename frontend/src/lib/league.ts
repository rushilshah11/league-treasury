import type { Address } from 'viem'
import type { EspnLink } from './espn'

/** Mirrors the contract's LeagueState enum. The order must match the contract. */
export const LeagueState = {
  Open: 0,
  Active: 1,
  StandingsSubmitted: 2,
  Disputed: 3,
  Finalized: 4,
  Cancelled: 5,
} as const
export type LeagueState = (typeof LeagueState)[keyof typeof LeagueState]

export const STATE_LABELS: Record<LeagueState, string> = {
  [LeagueState.Open]: 'Open',
  [LeagueState.Active]: 'In season',
  [LeagueState.StandingsSubmitted]: 'Standings posted',
  [LeagueState.Disputed]: 'Disputed',
  [LeagueState.Finalized]: 'Final',
  [LeagueState.Cancelled]: 'Cancelled',
}

/** Matches the contract's CHALLENGE_WINDOW and DISPUTE_RESOLUTION_WINDOW (seconds). */
export const CHALLENGE_WINDOW = 48 * 60 * 60
export const DISPUTE_RESOLUTION_WINDOW = 7 * 24 * 60 * 60

export type League = {
  id: bigint
  name: string
  /** The ESPN league this league follows. */
  espn: EspnLink
  commissioner: Address
  reporter: Address
  buyIn: bigint
  teamCount: number
  memberCount: number
  state: LeagueState
  joinDeadline: number
  standingsDeadline: number
  standingsSubmittedAt: number
  disputedAt: number
}

export type Member = {
  address: Address
  teamId: number
  finalPlace: number // 0 until standings are posted
  claimed: boolean
}

export function pot(league: League): bigint {
  return league.buyIn * BigInt(league.memberCount)
}

/** Approvals a dispute proposal needs to pass: more than half the members. Matches the contract. */
export function majority(league: League): number {
  return Math.floor(league.memberCount / 2) + 1
}

export function challengeWindowEnd(league: League): number {
  return league.standingsSubmittedAt + CHALLENGE_WINDOW
}

export function disputeResolutionEnd(league: League): number {
  return league.disputedAt + DISPUTE_RESOLUTION_WINDOW
}

/**
 * Mirrors the contract's isRefundable() using chain time, so the UI can show
 * the refund button at the same moment the contract starts allowing it.
 */
export function isRefundable(league: League, now: number): boolean {
  switch (league.state) {
    case LeagueState.Cancelled:
      return true
    case LeagueState.Open:
      return now >= league.joinDeadline
    case LeagueState.Active:
      return now >= league.standingsDeadline
    case LeagueState.Disputed:
      return now >= disputeResolutionEnd(league)
    default:
      return false
  }
}

/** Why a refund is available, in the user's terms. */
export function refundReason(league: League): string {
  switch (league.state) {
    case LeagueState.Cancelled:
      return 'This league was cancelled.'
    case LeagueState.Open:
      return "The league didn't fill before the join deadline."
    case LeagueState.Active:
      return 'Final standings were never posted before the deadline.'
    case LeagueState.Disputed:
      return "Members didn't agree on corrected standings in time."
    default:
      return ''
  }
}
