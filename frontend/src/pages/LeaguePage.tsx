import { PageShell } from '@/components/PageShell'
import { Text } from '@/components/typography'

export function LeaguePage() {
  return (
    <PageShell title="League">
      <Text variant="lead" className="max-w-[60ch]">
        Pot, members, standings and the action that's open right now: claim, dispute or refund.
      </Text>
    </PageShell>
  )
}
