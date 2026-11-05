import { formatEther, type Address } from 'viem'

/** 10000000000000000n -> "0.01 ETH" */
export function formatEth(wei: bigint, maxDecimals = 6): string {
  const [whole, fraction = ''] = formatEther(wei).split('.')
  const trimmed = fraction.slice(0, maxDecimals).replace(/0+$/, '')
  return `${whole}${trimmed ? `.${trimmed}` : ''} ETH`
}

/** 0x1234...abcd */
export function shortAddress(address: Address): string {
  return `${address.slice(0, 6)}…${address.slice(-4)}`
}

/** Unix seconds -> "Nov 11, 2026, 4:30 PM" */
export function formatDateTime(seconds: number): string {
  return new Date(seconds * 1000).toLocaleString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

/** Seconds -> "2d 4h", "3h 12m", "45m" */
export function formatDuration(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds))
  const days = Math.floor(s / 86400)
  const hours = Math.floor((s % 86400) / 3600)
  const minutes = Math.floor((s % 3600) / 60)
  if (days > 0) return `${days}d ${hours}h`
  if (hours > 0) return `${hours}h ${minutes}m`
  return `${Math.max(minutes, 1)}m`
}

/** Unix seconds -> value for <input type="datetime-local"> */
export function toDateTimeLocal(seconds: number): string {
  const d = new Date(seconds * 1000)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/** <input type="datetime-local"> value -> Unix seconds */
export function fromDateTimeLocal(value: string): number {
  return Math.floor(new Date(value).getTime() / 1000)
}

/** "3, 1, 2" -> [3, 1, 2]. Returns null if anything isn't a positive whole number. */
export function parseTeamIds(input: string): number[] | null {
  const parts = input
    .split(/[\s,]+/)
    .map((p) => p.trim())
    .filter(Boolean)
  if (parts.length === 0) return null
  const ids = parts.map(Number)
  return ids.every((n) => Number.isInteger(n) && n > 0) ? ids : null
}
