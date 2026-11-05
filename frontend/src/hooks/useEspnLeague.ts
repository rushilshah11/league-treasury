import { useQuery } from '@tanstack/react-query'
import { teamNames, type EspnLeague, type EspnLink } from '@/lib/espn'

/**
 * A public ESPN league, through our /api/espn endpoint (the browser can't call
 * ESPN directly). The server caches it until the weekly matchup rollover.
 */
export function useEspnLeague(link: EspnLink | undefined) {
  const enabled = !!link && link.leagueId > 0 && link.season > 0
  return useQuery({
    queryKey: ['espn', link?.sport, link?.season, link?.leagueId],
    enabled,
    staleTime: 5 * 60_000,
    retry: false,
    queryFn: async (): Promise<EspnLeague> => {
      const res = await fetch(`/api/espn/${link!.sport}/${link!.season}/${link!.leagueId}`)
      const body = await res.json().catch(() => ({}))
      if (!res.ok) throw new Error(body.error ?? "Couldn't load the ESPN league.")
      return body as EspnLeague
    },
  })
}

/** ESPN team names for a league (empty until loaded). */
export function useTeamNames(link: EspnLink | undefined): Map<number, string> {
  const { data } = useEspnLeague(link)
  return teamNames(data)
}
