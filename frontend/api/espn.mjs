// Vercel Function: the deployed version of the dev server's /api/espn endpoint.
// vercel.json rewrites /api/espn/:sport/:season/:leagueId to this function.
//
// Serverless functions don't keep memory between requests, so instead of an
// in-memory cache, the response tells Vercel's CDN to keep it until the weekly
// matchup rollover. Everyone who loads the league that week gets the cached copy.
import { EspnError, fetchEspnLeague, nextRollover } from '../server/espn.mjs'

export async function GET(request) {
  const params = new URL(request.url).searchParams
  const sport = params.get('sport') ?? ''
  const season = Number(params.get('season'))
  const leagueId = params.get('leagueId') ?? ''

  try {
    const league = await fetchEspnLeague(leagueId, { sport, season })
    const secondsToRollover = Math.max(60, Math.floor((nextRollover(sport) - Date.now()) / 1000))
    return Response.json(league, {
      headers: {
        'Cache-Control': 'public, max-age=300', // browsers: 5 minutes
        'Vercel-CDN-Cache-Control': `public, s-maxage=${secondsToRollover}`, // Vercel's CDN: until rollover
      },
    })
  } catch (err) {
    const status = err instanceof EspnError ? err.status : 502
    const error = err instanceof EspnError ? err.message : "Couldn't reach ESPN."
    return Response.json({ error }, { status, headers: { 'Cache-Control': 'no-store' } })
  }
}
