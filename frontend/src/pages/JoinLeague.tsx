import { PageShell } from '@/components/PageShell'
import { Text } from '@/components/typography'

export function JoinLeague() {
  return (
    <PageShell title="Join league">
      <Text variant="lead" className="max-w-[60ch]">
        You've been invited. Connect a wallet, pick your team and pay the buy-in.
      </Text>
    </PageShell>
  )
}
