import { useReadContract, useReadContracts } from 'wagmi'
import type { Address } from 'viem'
import { leagueTreasury } from '@/config/contracts'

export type StandingsProposal = {
  id: bigint
  proposer: Address
  approvals: number
  rankedTeamIds: number[]
  approvedByMe: boolean
}

/** Corrected standings members have proposed during a dispute, with vote counts. */
export function useProposals(leagueId: bigint, me: Address | undefined) {
  const count = useReadContract({ ...leagueTreasury, functionName: 'proposalCount', args: [leagueId] })
  const ids = Array.from({ length: Number(count.data ?? 0n) }, (_, i) => BigInt(i))

  const details = useReadContracts({
    contracts: ids.map((id) => ({ ...leagueTreasury, functionName: 'getProposal' as const, args: [leagueId, id] as const })),
    query: { enabled: ids.length > 0 },
  })
  const approvals = useReadContracts({
    contracts: ids.map((id) => ({
      ...leagueTreasury,
      functionName: 'hasApproved' as const,
      args: [leagueId, id, me!] as const,
    })),
    query: { enabled: ids.length > 0 && !!me },
  })

  const proposals: StandingsProposal[] = ids.flatMap((id, i) => {
    const result = details.data?.[i]?.result
    if (!result) return []
    const [proposer, votes, ranking] = result
    return [
      {
        id,
        proposer,
        approvals: votes,
        rankedTeamIds: ranking.map(Number),
        approvedByMe: approvals.data?.[i]?.result === true,
      },
    ]
  })

  return { proposals, isLoading: count.isLoading || details.isLoading }
}
