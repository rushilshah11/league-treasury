import type { IncomingMessage, ServerResponse } from 'node:http'
import type { EspnLeague } from '../src/lib/espn.ts'

export const SPORT_CODES: string[]

export class EspnError extends Error {
  status: number
  constructor(message: string, status: number)
}

type Options = { sport: string; season: number }

export function normalizeLeague(raw: unknown, sport: string): EspnLeague
export function fetchEspnLeague(leagueId: string | number, options: Options): Promise<EspnLeague>
export function getCachedLeague(leagueId: string | number, options: Options): Promise<EspnLeague>
export function nextRollover(sport: string, now?: Date): number
export function espnMiddleware(req: IncomingMessage, res: ServerResponse, next: () => void): void
