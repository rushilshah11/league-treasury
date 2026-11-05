// Reads a public ESPN fantasy league and trims it to what On-Chain Commish needs.
// Plain JavaScript so both the dev server (vite.config.ts) and the standings bot
// (scripts/report.mjs) can import it without a build step. Types: espn.d.mts.
//
// ESPN's fantasy API is unofficial and undocumented. Only public leagues work:
// the commissioner must turn on "viewable to public" in ESPN's league settings.

import { readFileSync } from 'node:fs'

const ESPN_API = 'https://lm-api-reads.fantasy.espn.com/apis/v3/games'

/** ESPN game codes we support: football, basketball, baseball, hockey. */
export const SPORT_CODES = ['ffl', 'fba', 'flb', 'fhl']

/** Day of the week (0 = Sunday) after which each sport's matchups are final. */
// Football's week ends with Monday Night Football; the other sports end Sunday.
const ROLLOVER_DAY = { ffl: 2, fba: 1, flb: 1, fhl: 1 }
const ROLLOVER_HOUR_ET = 9

export class EspnError extends Error {
  /** @param {string} message @param {number} status */
  constructor(message, status) {
    super(message)
    this.status = status
  }
}

/** Raw ESPN team -> EspnTeam (rank filled in later). */
function toTeam(raw) {
  const overall = raw.record?.overall ?? {}
  const name = raw.name ?? [raw.location, raw.nickname].filter(Boolean).join(' ')
  return {
    id: raw.id,
    name: name || `Team ${raw.id}`,
    abbrev: raw.abbrev ?? '',
    wins: overall.wins ?? 0,
    losses: overall.losses ?? 0,
    ties: overall.ties ?? 0,
    pointsFor: overall.pointsFor ?? 0,
    _finalRank: raw.rankCalculatedFinal ?? 0,
    _seed: raw.playoffSeed ?? 0,
    _pct: overall.percentage ?? 0,
  }
}

/** Raw ESPN league JSON -> EspnLeague. */
export function normalizeLeague(raw, sport) {
  const teams = (raw.teams ?? []).map(toTeam)
  const isFinal = teams.length > 0 && teams.every((t) => t._finalRank > 0)
  const hasSeeds = teams.length > 0 && teams.every((t) => t._seed > 0)

  // Final ranks once the season is over, otherwise ESPN's current seeding,
  // otherwise win percentage then points scored.
  teams.sort((a, b) => {
    if (isFinal) return a._finalRank - b._finalRank
    if (hasSeeds) return a._seed - b._seed
    return b._pct - a._pct || b.pointsFor - a.pointsFor
  })

  return {
    id: raw.id,
    sport,
    season: raw.seasonId,
    name: raw.settings?.name ?? `League ${raw.id}`,
    size: raw.settings?.size ?? teams.length,
    isFinal,
    currentMatchupPeriod: raw.status?.currentMatchupPeriod ?? 0,
    finalMatchupPeriod: raw.settings?.scheduleSettings?.matchupPeriodCount ?? 0,
    teams: teams.map(({ _finalRank, _seed, _pct, ...team }, i) => ({ ...team, rank: i + 1 })),
    fetchedAt: new Date().toISOString(),
  }
}

/** Fetches a league straight from ESPN (or the sample file, for offline testing). */
export async function fetchEspnLeague(leagueId, { sport, season }) {
  if (!/^\d+$/.test(String(leagueId))) throw new EspnError('ESPN league IDs are numbers.', 400)
  if (!SPORT_CODES.includes(sport)) throw new EspnError(`Unknown ESPN sport "${sport}".`, 400)
  if (!/^\d{4}$/.test(String(season))) throw new EspnError('The season must be a year, like 2027.', 400)

  // ESPN_FIXTURE=server/fixtures/sample-league.json serves saved data instead of calling ESPN.
  if (process.env.ESPN_FIXTURE) {
    const raw = JSON.parse(readFileSync(process.env.ESPN_FIXTURE, 'utf8'))
    return normalizeLeague({ ...raw, id: Number(leagueId), seasonId: Number(season) }, sport)
  }

  const url = `${ESPN_API}/${sport}/seasons/${season}/segments/0/leagues/${leagueId}?view=mTeam&view=mSettings&view=mStandings`
  const res = await fetch(url, { headers: { accept: 'application/json' } })
  if (res.status === 401 || res.status === 403) {
    throw new EspnError(
      'This ESPN league is private. The commissioner can make it viewable to the public in ESPN league settings.',
      403,
    )
  }
  if (res.status === 404) throw new EspnError(`No ESPN league ${leagueId} for the ${season} season.`, 404)
  if (!res.ok) throw new EspnError(`ESPN returned an error (${res.status}). Try again later.`, 502)
  return normalizeLeague(await res.json(), sport)
}

/** Next time matchups roll over, in ms: Monday 9am ET for basketball, Tuesday for football. */
export function nextRollover(sport, now = new Date()) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', {
      timeZone: 'America/New_York',
      weekday: 'short',
      hour: 'numeric',
      minute: 'numeric',
      hourCycle: 'h23',
    })
      .formatToParts(now)
      .map((p) => [p.type, p.value]),
  )
  const today = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(parts.weekday)
  const minutesNow = Number(parts.hour) * 60 + Number(parts.minute)
  const target = ROLLOVER_DAY[sport] ?? 1
  let days = (target - today + 7) % 7
  if (days === 0 && minutesNow >= ROLLOVER_HOUR_ET * 60) days = 7
  return now.getTime() + (days * 1440 + ROLLOVER_HOUR_ET * 60 - minutesNow) * 60_000
}

/** @type {Map<string, { league: object, expires: number }>} */
const cache = new Map()

/** Standings only change when a matchup ends, so keep each league until the weekly rollover. */
export async function getCachedLeague(leagueId, { sport, season }) {
  const key = `${sport}:${season}:${leagueId}`
  const hit = cache.get(key)
  if (hit && hit.expires > Date.now()) return hit.league
  const league = await fetchEspnLeague(leagueId, { sport, season })
  cache.set(key, { league, expires: nextRollover(sport) })
  return league
}

/**
 * Connect-style middleware for GET /api/espn/:sport/:season/:leagueId, e.g.
 * /api/espn/fba/2027/584507129. The dev server mounts it locally; a Vercel
 * function can call getCachedLeague the same way later.
 */
export function espnMiddleware(req, res, next) {
  const match = req.url?.match(/^\/api\/espn\/([^/?]+)\/([^/?]+)\/([^/?]+)/)
  if (!match || req.method !== 'GET') return next()
  res.setHeader('content-type', 'application/json')
  const [, sport, season, leagueId] = match
  getCachedLeague(leagueId, { sport, season: Number(season) })
    .then((league) => {
      res.statusCode = 200
      res.end(JSON.stringify(league))
    })
    .catch((err) => {
      res.statusCode = err instanceof EspnError ? err.status : 502
      res.end(JSON.stringify({ error: err instanceof EspnError ? err.message : "Couldn't reach ESPN." }))
    })
}
