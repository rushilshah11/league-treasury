import { useState, type FormEvent } from 'react'
import { useAccount } from 'wagmi'
import { BuyInBalance } from '@/components/BuyInBalance'
import { FormField } from '@/components/FormField'
import { SelectField } from '@/components/SelectField'
import { TxButton } from '@/components/TxButton'
import { leagueTreasury } from '@/config/contracts'
import { useBuyInApproval } from '@/hooks/useBuyInApproval'
import { useEspnLeague } from '@/hooks/useEspnLeague'
import { useTx } from '@/hooks/useTx'
import { formatUsdc } from '@/lib/format'
import type { League, Member } from '@/lib/league'

/** Pick your ESPN team and pay the buy-in. */
export function JoinForm({ league, members, onJoined }: { league: League; members: Member[]; onJoined: () => void }) {
  const [teamId, setTeamId] = useState('')
  const [inputError, setInputError] = useState<string>()
  const tx = useTx(onJoined)
  const { address } = useAccount()
  const approval = useBuyInApproval(address, league.buyIn)
  const taken = new Set(members.map((m) => m.teamId))
  const { data: espn } = useEspnLeague(league.espn)
  const openTeams = espn?.teams.filter((t) => !taken.has(t.id)).sort((a, b) => a.name.localeCompare(b.name))

  function submit(e: FormEvent) {
    e.preventDefault()
    const id = Number(teamId)
    if (!Number.isInteger(id) || id <= 0) return setInputError(espn ? 'Pick your team.' : 'Enter your team ID as a whole number.')
    if (taken.has(id)) return setInputError(`Team ${id} has already joined.`)
    setInputError(undefined)
    // Step 1: let the treasury pull the buy-in. The button flips once the allowance refetches.
    if (approval.needsApproval) return approval.approve()
    // Step 2: join. The treasury pulls the USDC itself, so no value is sent.
    tx.run((write) => write({ ...leagueTreasury, functionName: 'joinLeague', args: [league.id, id] }))
  }

  const step = approval.needsApproval ? approval.approveTx : tx

  return (
    <form onSubmit={submit} className="flex flex-col gap-6">
      {openTeams ? (
        <SelectField
          id="team-id"
          label="Your team"
          hint="Teams that already joined aren't listed."
          value={teamId}
          onChange={(e) => setTeamId(e.target.value)}
        >
          <option value="">Pick your ESPN team</option>
          {openTeams.map((team) => (
            <option key={team.id} value={team.id}>
              {team.name}
            </option>
          ))}
        </SelectField>
      ) : (
        <FormField
          id="team-id"
          label="Your ESPN team ID"
          hint={
            taken.size
              ? `Taken: ${[...taken].sort((a, b) => a - b).join(', ')}. Your commissioner can tell you your number.`
              : 'Your commissioner can tell you your number.'
          }
          inputMode="numeric"
          value={teamId}
          onChange={(e) => setTeamId(e.target.value)}
        />
      )}
      <div className="flex flex-col gap-2">
        <BuyInBalance balance={approval.balance} buyIn={league.buyIn} />
        <TxButton
          type="submit"
          disabled={!approval.loaded || approval.insufficient}
          phase={inputError ? 'error' : step.phase}
          error={inputError ?? step.error}
          label={
            approval.needsApproval
              ? `Approve ${formatUsdc(league.buyIn)}`
              : `Pay ${formatUsdc(league.buyIn)} and join`
          }
          pendingLabel={approval.needsApproval ? 'Approving…' : 'Joining…'}
        />
      </div>
    </form>
  )
}
