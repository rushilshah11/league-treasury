/** Total basis points in a payout table (100%). Matches the contract's TOTAL_BPS. */
export const TOTAL_BPS = 10_000

/**
 * Linear payout table in basis points, index 0 = 1st place.
 * Place k gets weight (teamCount - k + 1); the rounding remainder goes to 1st place,
 * so the table always sums to exactly 10,000, which the contract requires.
 */
export function linearPayoutBps(teamCount: number): number[] {
  const weightSum = (teamCount * (teamCount + 1)) / 2
  const bps = Array.from({ length: teamCount }, (_, i) =>
    Math.floor((TOTAL_BPS * (teamCount - i)) / weightSum),
  )
  const remainder = TOTAL_BPS - bps.reduce((a, b) => a + b, 0)
  bps[0] += remainder
  return bps
}

/** Each place's payout in wei, matching the contract's getPayout (1st place gets the rounding dust). */
export function payoutAmounts(pot: bigint, bps: number[]): bigint[] {
  const amounts = bps.map((b) => (pot * BigInt(b)) / BigInt(TOTAL_BPS))
  const othersTotal = amounts.slice(1).reduce((a, b) => a + b, 0n)
  amounts[0] = pot - othersTotal
  return amounts
}

/** 1333 -> "13.33%" */
export function formatBps(bps: number): string {
  return `${(bps / 100).toFixed(2)}%`
}
