# League Treasury: Spec (v1)

## Overview
A contract that holds a fantasy basketball league's buy-ins and pays every
team out by final finish. Test tokens only.

## Roles
- **Commissioner:** creates the league and sets its rules.
- **Member:** joins by paying the buy-in and registering their ESPN team ID.
- **Reporter:** the standings bot. The only address that can submit standings.

## League lifecycle
1. **OPEN:** league created; members can join until the join deadline.
2. **ACTIVE:** league is full; the season is in progress; funds are locked.
3. **STANDINGS_SUBMITTED:** reporter submitted final standings; 48-hour
   challenge window is running.
4. **DISPUTED:** a member flagged the standings during the window.
5. **FINALIZED:** window closed with no open dispute; members can claim.

## Payout rules
- Every place gets a share of the pot. Payout table is in basis points
  (10,000 = 100%), index 0 = 1st place, and must sum to exactly 10,000.
- Default curve is linear: weight for place k = (teamCount - k + 1).
  14 teams: 1st ≈ 13.3%, 14th ≈ 1%.
- Rounding remainders go to 1st place, so payouts sum to exactly the pot.
- Each member claims their own payout once.

## Open decisions
1. **DECIDE: League doesn't fill by the join deadline.**
   Default: league is cancelled; every member who joined can withdraw
   their buy-in.
2. **DECIDE: Who resolves a dispute?**
   Default: the commissioner submits corrected standings, which starts a
   new 48-hour window.
3. **DECIDE: Reporter never submits standings.**
   Default: if no standings arrive by a deadline set at league creation
   (e.g., 30 days after season end), every member can withdraw their buy-in.
4. **DECIDE: Can the commissioner cancel a league?**
   Default: only while OPEN; members can then withdraw their buy-ins.

## Invariant
Funds can never be stuck: every state has a path that returns money to
members.