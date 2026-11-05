import { leagueTreasury } from '@/config/contracts'
import { useTx } from '@/hooks/useTx'
import type { League, Member } from '@/lib/league'
import { ActionCard } from '../ActionCard'
import { RankingForm } from '../RankingForm'

/** Shown to the reporter. Later the standings bot does this automatically. */
export function SubmitStandingsAction({ league, members }: { league: League; members: Member[] }) {
  const tx = useTx()
  return (
    <ActionCard
      title="Post final standings"
      description="You're this league's standings reporter. Posting standings opens a 48-hour window for members to dispute them."
    >
      <RankingForm
        id="standings"
        members={members}
        phase={tx.phase}
        error={tx.error}
        label="Post standings"
        pendingLabel="Posting…"
        onSubmit={(ranking) =>
          tx.run((write) =>
            write({ ...leagueTreasury, functionName: 'submitStandings', args: [league.id, ranking] }),
          )
        }
      />
    </ActionCard>
  )
}
