import { PageShell } from '@/components/PageShell'
import { Text } from '@/components/typography'

export function CreateLeague() {
  return (
    <PageShell title="Create a league">
      <Text variant="lead" className="max-w-[60ch]">
        Set your league's name, buy-in, team count and deadlines. When the league is created, you'll get an invite link to share with your league.
      </Text>
    </PageShell>
  )
}
