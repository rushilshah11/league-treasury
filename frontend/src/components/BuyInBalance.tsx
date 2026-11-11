import { Text } from '@/components/typography'
import { formatUsdc } from '@/lib/format'

/** "You have $3.20, buy-in is $20.00": shown by the pay button so a short balance is obvious before signing. */
export function BuyInBalance({ balance, buyIn }: { balance: bigint | undefined; buyIn: bigint }) {
  if (balance === undefined || buyIn <= 0n) return null
  const short = balance < buyIn
  return (
    <Text variant="small" className={short ? 'text-destructive' : undefined}>
      You have {formatUsdc(balance)}{short ? `, buy-in is ${formatUsdc(buyIn)}` : ''}.
    </Text>
  )
}
