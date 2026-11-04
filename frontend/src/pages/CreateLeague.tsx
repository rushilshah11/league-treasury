import { PageShell } from '../components/PageShell'

export function CreateLeague() {
  return (
    <PageShell title="Create a league">
      <p className="max-w-[60ch] text-lg leading-relaxed text-dust">
        Set your league's name, buy-in, team count and deadlines. When the league is created, you'll get an invite link to share with your league.
      </p>
    </PageShell>
  )
}
