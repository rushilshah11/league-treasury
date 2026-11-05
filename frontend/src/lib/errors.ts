import { BaseError, ContractFunctionRevertedError, UserRejectedRequestError } from 'viem'

/**
 * Plain-language messages for the contract's custom errors. viem decodes the
 * revert using the ABI, so we get the error's name instead of "execution reverted".
 */
const CONTRACT_ERRORS: Record<string, string> = {
  InvalidName: 'League name must be between 1 and 64 characters.',
  InvalidTeamCount: 'A league needs at least 2 teams.',
  PayoutLengthMismatch: 'The payout table must have one entry per team.',
  InvalidBuyIn: 'The buy-in must be more than zero.',
  InvalidReporter: 'Enter a valid standings reporter address.',
  InvalidJoinDeadline: 'The join deadline must be in the future.',
  InvalidStandingsDeadline: 'The standings deadline must be after the join deadline.',
  InvalidPayoutTotal: 'The payout table must add up to 100%.',
  LeagueNotFound: "This league doesn't exist.",
  LeagueNotOpen: 'This league is no longer taking new members.',
  JoinDeadlinePassed: 'The join deadline has passed.',
  InvalidTeamId: "That team ID isn't valid for this league.",
  TeamAlreadyTaken: 'Someone already joined with that team.',
  IncorrectBuyIn: 'The amount sent must match the buy-in exactly.',
  MemberAlreadyJoined: "You've already joined this league.",
  InvalidState: "That action isn't available at this stage of the league.",
  NotReporter: 'Only the standings reporter can post standings.',
  StandingsDeadlinePassed: 'The deadline for posting standings has passed.',
  RankingLengthMismatch: 'List every team exactly once.',
  DuplicateTeam: 'A team is listed more than once.',
  NotCommissioner: 'Only the commissioner can do that.',
  NotMember: "You're not a member of this league.",
  ChallengeWindowClosed: 'The 48-hour dispute window has closed.',
  ChallengeWindowOpen: "The 48-hour dispute window hasn't closed yet.",
  AlreadyClaimed: "You've already withdrawn your money from this league.",
  TransferFailed: "The payment couldn't be sent to your wallet.",
  NotRefundable: 'Refunds are not available for this league right now.',
  DisputeResolutionWindowClosed: 'Voting on this dispute has closed.',
  ReporterCannotPlay: "The standings reporter can't have a team in the league.",
  ProposalNotFound: "That proposal doesn't exist.",
  AlreadyApproved: "You've already approved these standings.",
}

export function describeError(error: unknown): string {
  if (error instanceof BaseError) {
    if (error.walk((e) => e instanceof UserRejectedRequestError)) {
      return 'You cancelled the request in your wallet.'
    }
    const reverted = error.walk((e) => e instanceof ContractFunctionRevertedError)
    if (reverted instanceof ContractFunctionRevertedError) {
      const name = reverted.data?.errorName?.replace(/^LeagueTreasury__/, '')
      if (name) return CONTRACT_ERRORS[name] ?? name
    }
    return error.shortMessage
  }
  return error instanceof Error ? error.message : 'Something went wrong.'
}
