import { PageShell } from '@/components/PageShell'
import { Text } from '@/components/typography'

export function MyLeagues() {
  return (
    <PageShell title="My leagues">
      <Text variant="lead" className="max-w-[60ch]">
        Every league you run or have joined will show up here, with what needs your attention first.
      </Text>
    </PageShell>
  )
}
