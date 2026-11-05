import { useState, type FormEvent } from 'react'
import { FormField } from '@/components/FormField'
import { SelectField } from '@/components/SelectField'
import { TxButton } from '@/components/TxButton'
import { leagueTreasury } from '@/config/contracts'
import { useEspnLeague } from '@/hooks/useEspnLeague'
import { useTx } from '@/hooks/useTx'
import { formatEth } from '@/lib/format'
import type { League, Member } from '@/lib/league'

/** Pick your ESPN team and pay the buy-in. */
export function JoinForm({ league, members, onJoined }: { league: League; members: Member[]; onJoined: () => void }) {
  const [teamId, setTeamId] = useState('')
  const [inputError, setInputError] = useState<string>()
  const tx = useTx(onJoined)
  const taken = new Set(members.map((m) => m.teamId))
  const { data: espn } = useEspnLeague(league.espn)
  const openTeams = espn?.teams.filter((t) => !taken.has(t.id)).sort((a, b) => a.name.localeCompare(b.name))

  function submit(e: FormEvent) {
    e.preventDefault()
    const id = Number(teamId)
    if (!Number.isInteger(id) || id <= 0) return setInputError(espn ? 'Pick your team.' : 'Enter your team ID as a whole number.')
    if (taken.has(id)) return setInputError(`Team ${id} has already joined.`)
    setInputError(undefined)
    tx.run((write) =>
      write({ ...leagueTreasury, functionName: 'joinLeague', args: [league.id, id], value: league.buyIn }),
    )
  }

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
      <TxButton
        type="submit"
        phase={inputError ? 'error' : tx.phase}
        error={inputError ?? tx.error}
        label={`Pay ${formatEth(league.buyIn)} and join`}
        pendingLabel="Joining…"
      />
    </form>
  )
}
