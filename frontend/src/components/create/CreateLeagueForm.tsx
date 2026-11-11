import { useState, type FormEvent } from 'react'
import { isAddressEqual, parseUnits, parseEventLogs, type Address, type TransactionReceipt } from 'viem'
import { BuyInBalance } from '@/components/BuyInBalance'
import { FormField } from '@/components/FormField'
import { Section } from '@/components/Section'
import { SelectField } from '@/components/SelectField'
import { TxButton } from '@/components/TxButton'
import { PayoutTable } from '@/components/league/PayoutTable'
import { Text } from '@/components/typography'
import { leagueTreasury } from '@/config/contracts'
import { REPORTER_ADDRESS } from '@/config/reporter'
import { useBuyInApproval } from '@/hooks/useBuyInApproval'
import { useTx } from '@/hooks/useTx'
import { sportIndex, type EspnLeague, type SportCode } from '@/lib/espn'
import { USDC_DECIMALS, formatUsdc, fromDateTimeLocal, shortAddress, toDateTimeLocal } from '@/lib/format'
import { linearPayoutBps } from '@/lib/payouts'
import { EspnLookup } from './EspnLookup'

const DAY = 24 * 60 * 60
const MIN_TEAMS = 2
const MAX_TEAMS = 20

type Draft = {
  name: string
  teamId: string
  buyIn: string
  joinDeadline: string
  standingsDeadline: string
}

function initialDraft(espn: EspnLeague): Draft {
  const now = Math.floor(Date.now() / 1000)
  return {
    name: espn.name.slice(0, 64),
    teamId: '',
    buyIn: '20',
    joinDeadline: toDateTimeLocal(now + 7 * DAY),
    standingsDeadline: toDateTimeLocal(now + 180 * DAY),
  }
}

/** Checks the draft the same way the contract will, so mistakes show before signing. */
function validate(d: Draft, espn: EspnLeague, me: Address): string | null {
  if (!d.name.trim()) return 'Give your league a name.'
  if (espn.size < MIN_TEAMS || espn.size > MAX_TEAMS)
    return `On-Chain Commish supports leagues of ${MIN_TEAMS} to ${MAX_TEAMS} teams.`
  if (!espn.teams.some((t) => t.id === Number(d.teamId))) return 'Pick your team.'
  // Whole cents only: formatUsdc shows two decimals, so a buy-in like 20.123456 would be
  // displayed as $20.12 while the contract charges $20.123456. Display and charge must match.
  if (!/^\d+(\.\d{1,2})?$/.test(d.buyIn.trim())) return 'Enter the buy-in in dollars and cents, like 20 or 12.50.'
  if (parseUnits(d.buyIn.trim(), USDC_DECIMALS) <= 0n) return 'Buy-in must be more than 0.'
  const join = fromDateTimeLocal(d.joinDeadline)
  const standings = fromDateTimeLocal(d.standingsDeadline)
  if (!(join > Date.now() / 1000)) return 'The join deadline must be in the future.'
  if (!(standings > join)) return 'Standings must be due after the join deadline.'
  if (isAddressEqual(REPORTER_ADDRESS, me)) return "This wallet is the standings bot's, so it can't play in a league."
  return null
}

function leagueIdFrom(receipt: TransactionReceipt): bigint | undefined {
  const [log] = parseEventLogs({ abi: leagueTreasury.abi, eventName: 'LeagueCreated', logs: receipt.logs })
  return log?.args.leagueId
}

type CreateLeagueFormProps = { me: Address; onCreated: (leagueId: bigint) => void }

/** Step 1: find the ESPN league. Step 2: set the money rules. */
export function CreateLeagueForm({ me, onCreated }: CreateLeagueFormProps) {
  const [espn, setEspn] = useState<EspnLeague>()
  return (
    <div className="flex flex-col gap-12">
      <Section title="ESPN league">
        <EspnLookup onFound={setEspn} />
      </Section>
      {espn && <LeagueDetailsForm key={espn.id} espn={espn} me={me} onCreated={onCreated} />}
    </div>
  )
}

function LeagueDetailsForm({ espn, me, onCreated }: CreateLeagueFormProps & { espn: EspnLeague }) {
  const [draft, setDraft] = useState(() => initialDraft(espn))
  const [inputError, setInputError] = useState<string>()
  const tx = useTx((receipt) => {
    const id = leagueIdFrom(receipt)
    if (id !== undefined) onCreated(id)
  })

  const field = (key: keyof Draft) => ({
    value: draft[key],
    onChange: (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
      setDraft({ ...draft, [key]: e.target.value }),
  })

  const teams = espn.size
  let buyIn = 0n
  try {
    buyIn = parseUnits(draft.buyIn.trim(), USDC_DECIMALS)
  } catch {
    /* preview shows 0 until the buy-in parses */
  }
  const approval = useBuyInApproval(me, buyIn)
  const step = approval.needsApproval ? approval.approveTx : tx

  function submit(e: FormEvent) {
    e.preventDefault()
    const problem = validate(draft, espn, me)
    setInputError(problem ?? undefined)
    if (problem) return
    // Step 1: let the treasury pull the commissioner's buy-in. The button flips once the allowance refetches.
    if (approval.needsApproval) return approval.approve()
    // Step 2: create. The treasury pulls the USDC itself, so no value is sent.
    tx.run((write) =>
      write({
        ...leagueTreasury,
        functionName: 'createLeague',
        args: [
          draft.name.trim(),
          { leagueId: BigInt(espn.id), season: espn.season, sport: sportIndex(espn.sport as SportCode) },
          REPORTER_ADDRESS,
          buyIn,
          teams,
          BigInt(fromDateTimeLocal(draft.joinDeadline)),
          BigInt(fromDateTimeLocal(draft.standingsDeadline)),
          linearPayoutBps(teams),
          Number(draft.teamId),
        ],
      }),
    )
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-12">
      <Section title="League">
        <div className="grid gap-6 sm:grid-cols-2">
          <FormField id="name" label="League name" maxLength={64} {...field('name')} />
          <SelectField
            id="team-id"
            label="Your team"
            hint="You play in your own league, so you pay the buy-in when you create it."
            {...field('teamId')}
          >
            <option value="">Pick your ESPN team</option>
            {[...espn.teams]
              .sort((a, b) => a.name.localeCompare(b.name))
              .map((team) => (
                <option key={team.id} value={team.id}>
                  {team.name}
                </option>
              ))}
          </SelectField>
          <FormField
            id="buy-in"
            label="Buy-in (USDC)"
            inputMode="decimal"
            hint={`Test USDC only. All ${teams} teams pay this to join.`}
            {...field('buyIn')}
          />
        </div>
      </Section>

      <Section title="Deadlines">
        <div className="grid gap-6 sm:grid-cols-2">
          <FormField
            id="join-deadline"
            label="Join by"
            type="datetime-local"
            hint="If the league isn't full by then, everyone can withdraw their buy-in."
            {...field('joinDeadline')}
          />
          <FormField
            id="standings-deadline"
            label="Final standings due by"
            type="datetime-local"
            hint="Pick a few days after your fantasy playoffs end. If standings aren't posted by then, everyone can withdraw their buy-in."
            {...field('standingsDeadline')}
          />
        </div>
      </Section>

      <Section title="Final standings">
        <Text variant="muted" measure="readable">
          The On-Chain Commish bot posts your final standings from ESPN after the season ({shortAddress(REPORTER_ADDRESS)}).
          No one in the league, including you, can post them.
        </Text>
      </Section>

      <Section title="Payouts">
        <Text variant="small">Split across all {teams} places, from a pot of {formatUsdc(buyIn * BigInt(teams))}.</Text>
        <PayoutTable payoutBps={linearPayoutBps(teams)} pot={buyIn * BigInt(teams)} />
      </Section>

      <div className="flex flex-col gap-2">
        <BuyInBalance balance={approval.balance} buyIn={buyIn} />
        <TxButton
          type="submit"
          disabled={!approval.loaded || approval.insufficient}
          phase={inputError ? 'error' : step.phase}
          error={inputError ?? step.error}
          label={
            buyIn <= 0n
              ? 'Create league'
              : approval.needsApproval
                ? `Approve ${formatUsdc(buyIn)}`
                : `Pay ${formatUsdc(buyIn)} and create league`
          }
          pendingLabel={approval.needsApproval ? 'Approving…' : 'Creating…'}
        />
      </div>
    </form>
  )
}
