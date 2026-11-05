import { useParams } from 'react-router-dom'

/** The league id from the URL (/league/:leagueId), or undefined if it isn't a number. */
export function useLeagueId(): bigint | undefined {
  const { leagueId } = useParams()
  return leagueId && /^\d+$/.test(leagueId) ? BigInt(leagueId) : undefined
}
