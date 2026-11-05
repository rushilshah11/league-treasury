/** One ESPN team, trimmed to what the app shows. */
export type EspnTeam = {
  /** ESPN's team ID. Members join the contract with this number. */
  id: number
  name: string
  abbrev: string
  wins: number
  losses: number
  ties: number
  pointsFor: number
  /** Current standing (1 = first). Becomes the final rank once the season is over. */
  rank: number
}

/** An ESPN league, as returned by /api/espn/:leagueId. */
export type EspnLeague = {
  id: number
  /** ESPN's game code: fba = basketball, ffl = football. */
  sport: string
  season: number
  name: string
  size: number
  /** True once ESPN has final ranks for every team (playoffs included). */
  isFinal: boolean
  currentMatchupPeriod: number
  finalMatchupPeriod: number
  /** Teams in standings order. */
  teams: EspnTeam[]
  fetchedAt: string
}

export type EspnError = { error: string }

/**
 * ESPN fantasy sports, in the contract's Sport enum order (index = enum value).
 * `code` is ESPN's game code in its API URLs; `path` is the sport in fantasy.espn.com URLs.
 */
export const SPORTS = [
  { code: 'ffl', path: 'football', label: 'Football' },
  { code: 'fba', path: 'basketball', label: 'Basketball' },
  { code: 'flb', path: 'baseball', label: 'Baseball' },
  { code: 'fhl', path: 'hockey', label: 'Hockey' },
] as const
export type SportCode = (typeof SPORTS)[number]['code']

/** Which ESPN league a league follows, as recorded on-chain. */
export type EspnLink = { leagueId: number; season: number; sport: SportCode }

export function sportIndex(code: SportCode): number {
  return SPORTS.findIndex((s) => s.code === code)
}

export function sportLabel(code: SportCode): string {
  return SPORTS.find((s) => s.code === code)?.label ?? code
}

/** Basketball and hockey seasons span two years; ESPN names them by the later one. */
function spansTwoYears(code: SportCode): boolean {
  return code === 'fba' || code === 'fhl'
}

/** "Basketball 2026-27" or "Football 2026" */
export function seasonLabel(code: SportCode, season: number): string {
  const years = spansTwoYears(code) ? `${season - 1}-${String(season).slice(2)}` : `${season}`
  return `${sportLabel(code)} ${years}`
}

/** The season ESPN is most likely on for a sport right now. */
export function currentSeason(code: SportCode, now = new Date()): number {
  const year = now.getFullYear()
  const month = now.getMonth() // 0 = January
  if (spansTwoYears(code)) return month >= 7 ? year + 1 : year // new season from August
  if (code === 'ffl') return month <= 1 ? year - 1 : year // football runs into January
  return year
}

/**
 * Reads an ESPN league URL like fantasy.espn.com/basketball/team?leagueId=584507129&seasonId=2027,
 * or a bare league ID. Sport and season are filled in only when the URL has them.
 */
export function parseEspnInput(input: string): { leagueId?: number; sport?: SportCode; season?: number } {
  const text = input.trim()
  if (/^\d+$/.test(text)) return { leagueId: Number(text) }
  try {
    const url = new URL(text.startsWith('http') ? text : `https://${text}`)
    const leagueId = Number(url.searchParams.get('leagueId'))
    const season = Number(url.searchParams.get('seasonId'))
    const sport = SPORTS.find((s) => url.pathname.split('/').includes(s.path))?.code
    return {
      leagueId: leagueId > 0 ? leagueId : undefined,
      season: season > 0 ? season : undefined,
      sport,
    }
  } catch {
    return {}
  }
}

/** ESPN team ID -> team name. */
export function teamNames(league: EspnLeague | undefined): Map<number, string> {
  return new Map(league?.teams.map((t) => [t.id, t.name]) ?? [])
}

/** A team's name if ESPN knows it, otherwise "Team 3". */
export function teamLabel(names: Map<number, string>, teamId: number): string {
  return names.get(teamId) ?? `Team ${teamId}`
}

/** "8-2" or "8-2-1" with ties. */
export function formatRecord(team: EspnTeam): string {
  return team.ties ? `${team.wins}-${team.losses}-${team.ties}` : `${team.wins}-${team.losses}`
}
