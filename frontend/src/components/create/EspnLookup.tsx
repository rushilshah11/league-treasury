import { useEffect, useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { FormField } from '@/components/FormField'
import { SelectField } from '@/components/SelectField'
import { Text } from '@/components/typography'
import { useEspnLeague } from '@/hooks/useEspnLeague'
import {
  SPORTS,
  currentSeason,
  parseEspnInput,
  seasonLabel,
  type EspnLeague,
  type EspnLink,
  type SportCode,
} from '@/lib/espn'

/**
 * Find a public ESPN league. Pasting the league's URL fills in the sport and
 * season; a bare ID uses the sport and season fields. Calls onFound once ESPN returns it.
 */
export function EspnLookup({ onFound }: { onFound: (league: EspnLeague) => void }) {
  const [input, setInput] = useState('')
  const [sport, setSport] = useState<SportCode>('fba')
  const [season, setSeason] = useState(() => String(currentSeason('fba')))
  const [link, setLink] = useState<EspnLink>()
  const [inputError, setInputError] = useState<string>()
  const { data, error, isFetching } = useEspnLeague(link)

  useEffect(() => {
    if (data) onFound(data)
  }, [data, onFound])

  // A pasted URL carries its own sport and season; copy them into the fields.
  function changeInput(value: string) {
    setInput(value)
    const parsed = parseEspnInput(value)
    if (parsed.sport) setSport(parsed.sport)
    if (parsed.season) setSeason(String(parsed.season))
    else if (parsed.sport) setSeason(String(currentSeason(parsed.sport)))
  }

  function changeSport(value: SportCode) {
    setSport(value)
    setSeason(String(currentSeason(value)))
  }

  function submit(e: FormEvent) {
    e.preventDefault()
    const { leagueId } = parseEspnInput(input)
    if (!leagueId) return setInputError('Paste your ESPN league URL, or the number after leagueId= in it.')
    if (!/^\d{4}$/.test(season)) return setInputError('The season is a year, like 2027.')
    setInputError(undefined)
    setLink({ leagueId, sport, season: Number(season) })
  }

  const problem = inputError ?? error?.message
  return (
    <form onSubmit={submit} className="flex flex-col gap-6">
      <FormField
        id="espn"
        label="ESPN league link or ID"
        placeholder="https://fantasy.espn.com/basketball/league?leagueId=…"
        hint="Your league must be viewable to the public. Turn that on in ESPN's league settings."
        spellCheck={false}
        value={input}
        onChange={(e) => changeInput(e.target.value)}
      />
      <div className="grid gap-6 sm:grid-cols-2">
        <SelectField id="sport" label="Sport" value={sport} onChange={(e) => changeSport(e.target.value as SportCode)}>
          {SPORTS.map((s) => (
            <option key={s.code} value={s.code}>
              {s.label}
            </option>
          ))}
        </SelectField>
        <FormField
          id="season"
          label="Season"
          inputMode="numeric"
          hint={/^\d{4}$/.test(season) ? seasonLabel(sport, Number(season)) : 'The year ESPN uses in seasonId='}
          value={season}
          onChange={(e) => setSeason(e.target.value)}
        />
      </div>
      <div>
        <Button type="submit" variant="outline" size="lg" disabled={isFetching}>
          {isFetching ? 'Finding…' : 'Find league'}
        </Button>
      </div>
      {problem && (
        <Alert variant="destructive">
          <AlertDescription className="text-destructive">{problem}</AlertDescription>
        </Alert>
      )}
      {data && !problem && (
        <Text variant="body">
          Found <span className="font-bold">{data.name}</span>: {data.size} teams,{' '}
          {seasonLabel(data.sport as SportCode, data.season)}.
        </Text>
      )}
    </form>
  )
}
