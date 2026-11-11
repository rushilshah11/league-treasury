import { erc20Abi } from 'viem'
import { useReadContract } from 'wagmi'
import { leagueTreasury } from '@/config/contracts'

/**
 * The USDC token the treasury takes buy-ins in, ready to spread into wagmi calls:
 * `useReadContract({ ...usdc, functionName: 'balanceOf', args: [me] })`.
 *
 * The address is read from the treasury itself rather than configured separately,
 * so the frontend can never point at a different token than the contract uses.
 * `usdc` is undefined until that read resolves.
 */
export function useUsdc() {
  // The token address is immutable in the contract, so cache it for the whole session.
  const { data: address, isLoading, error } = useReadContract({
    ...leagueTreasury,
    functionName: 'usdc',
    query: { staleTime: Infinity },
  })
  return {
    usdc: address ? ({ address, abi: erc20Abi } as const) : undefined,
    isLoading,
    error,
  }
}
