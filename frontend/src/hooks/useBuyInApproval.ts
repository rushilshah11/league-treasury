import { erc20Abi, type Address } from 'viem'
import { useReadContract } from 'wagmi'
import { leagueTreasury } from '@/config/contracts'
import { useTx } from '@/hooks/useTx'
import { useUsdc } from '@/hooks/useUsdc'

/**
 * What `owner` needs before paying a `buyIn` into the treasury.
 *
 * The treasury pulls the buy-in with `transferFrom`, so the owner must first approve
 * the treasury (the spender) for at least that amount on the USDC contract.
 *
 * We approve exactly the buy-in, not unlimited. It costs a second wallet pop-up per
 * league, but the treasury can never take more than one buy-in: if the contract had
 * a bug, an unlimited approval would let it pull every dollar the user holds.
 *
 * Approve and pay are two separate transactions, so if the approve lands and the pay
 * fails (e.g. someone else took the team in between), the approval stays behind. That's
 * harmless (one buy-in, to a contract they were about to pay), and batching both into
 * one atomic call removes it.
 */
export function useBuyInApproval(owner: Address | undefined, buyIn: bigint) {
  const { usdc } = useUsdc()
  const enabled = usdc !== undefined && owner !== undefined

  const balance = useReadContract({
    address: usdc?.address,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: owner ? [owner] : undefined,
    query: { enabled },
  })
  const allowance = useReadContract({
    address: usdc?.address,
    abi: erc20Abi,
    functionName: 'allowance',
    args: owner ? [owner, leagueTreasury.address] : undefined,
    query: { enabled },
  })
  // useTx already refreshes every read on success; refetching here makes the button flip explicit.
  const approveTx = useTx(() => allowance.refetch())

  const loaded = balance.data !== undefined && allowance.data !== undefined
  return {
    /** Both reads have resolved, so the flags below are meaningful. */
    loaded,
    balance: balance.data,
    /** The owner holds less than the buy-in, so paying would revert. */
    insufficient: loaded && balance.data < buyIn,
    /** The treasury isn't allowed to pull the buy-in yet. */
    needsApproval: loaded && allowance.data < buyIn,
    approve: () => {
      if (!usdc) return
      approveTx.run((write) => write({ ...usdc, functionName: 'approve', args: [leagueTreasury.address, buyIn] }))
    },
    approveTx,
  }
}
