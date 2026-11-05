import { useState } from 'react'
import { useAccount } from 'wagmi'
import { ConnectPrompt } from '@/components/ConnectPrompt'
import { PageShell } from '@/components/PageShell'
import { Text } from '@/components/typography'
import { CreateLeagueForm } from '@/components/create/CreateLeagueForm'
import { LeagueCreated } from '@/components/create/LeagueCreated'

export function CreateLeague() {
  const { address } = useAccount()
  const [createdId, setCreatedId] = useState<bigint>()

  if (createdId !== undefined) {
    return (
      <PageShell title="League created">
        <LeagueCreated leagueId={createdId} />
      </PageShell>
    )
  }

  return (
    <PageShell title="Create a league">
      <Text variant="lead" measure="readable">
        Start with your ESPN league. Then set the buy-in and deadlines. When it's created, you'll get an invite link to share.
      </Text>
      {address ? (
        <CreateLeagueForm key={address} me={address} onCreated={setCreatedId} />
      ) : (
        <ConnectPrompt>Connect your wallet to create a league. You'll be its commissioner.</ConnectPrompt>
      )}
    </PageShell>
  )
}
