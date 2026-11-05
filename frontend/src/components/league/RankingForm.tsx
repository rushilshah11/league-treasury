import { useState, type FormEvent } from 'react'
import { FormField } from '@/components/FormField'
import { TxButton } from '@/components/TxButton'
import type { TxPhase } from '@/hooks/useTx'
import { parseTeamIds } from '@/lib/format'
import type { Member } from '@/lib/league'

type RankingFormProps = {
  id: string
  members: Member[]
  phase: TxPhase
  error?: string
  label: string
  pendingLabel: string
  onSubmit: (rankedTeamIds: number[]) => void
}

/** Enter final standings as team IDs in finishing order (1st place first). */
export function RankingForm({ id, members, phase, error, label, pendingLabel, onSubmit }: RankingFormProps) {
  // Starts as the current order (members can load after first render); undefined until edited.
  const [edited, setEdited] = useState<string>()
  const value = edited ?? members.map((m) => m.teamId).join(', ')
  const [inputError, setInputError] = useState<string>()

  function submit(e: FormEvent) {
    e.preventDefault()
    const ids = parseTeamIds(value)
    if (!ids) return setInputError('Enter team IDs as whole numbers, separated by commas.')
    if (ids.length !== members.length) return setInputError(`List all ${members.length} teams.`)
    setInputError(undefined)
    onSubmit(ids)
  }

  return (
    <form onSubmit={submit} className="flex flex-col gap-5">
      <FormField
        id={id}
        label="Team IDs in finishing order"
        hint="First place first, separated by commas."
        value={value}
        onChange={(e) => setEdited(e.target.value)}
        aria-invalid={!!inputError}
      />
      <TxButton
        type="submit"
        phase={inputError ? 'error' : phase}
        error={inputError ?? error}
        label={label}
        pendingLabel={pendingLabel}
      />
    </form>
  )
}
