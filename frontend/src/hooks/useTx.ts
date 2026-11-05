import { useEffect, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import type { Hash, TransactionReceipt } from 'viem'
import { describeError } from '@/lib/errors'

export type TxPhase = 'idle' | 'signing' | 'pending' | 'success' | 'error'

/**
 * One contract transaction and its lifecycle:
 * idle -> signing (wallet open) -> pending (waiting for a block) -> success | error.
 * On success, every cached chain read refreshes so the page shows the new state.
 */
export function useTx(onSuccess?: (receipt: TransactionReceipt) => void) {
  const { writeContractAsync } = useWriteContract()
  const queryClient = useQueryClient()
  const [hash, setHash] = useState<Hash>()
  const [phase, setPhase] = useState<TxPhase>('idle')
  const [error, setError] = useState<string>()
  const receipt = useWaitForTransactionReceipt({ hash })

  useEffect(() => {
    if (!hash || phase !== 'pending') return
    if (receipt.isSuccess) {
      if (receipt.data.status === 'success') {
        setPhase('success')
        queryClient.invalidateQueries()
        onSuccess?.(receipt.data)
      } else {
        setPhase('error')
        setError('The transaction was reverted.')
      }
    } else if (receipt.isError) {
      setPhase('error')
      setError(describeError(receipt.error))
    }
  }, [hash, phase, receipt.isSuccess, receipt.isError, receipt.data, receipt.error, queryClient, onSuccess])

  async function run(send: (write: typeof writeContractAsync) => Promise<Hash>) {
    setPhase('signing')
    setError(undefined)
    try {
      setHash(await send(writeContractAsync))
      setPhase('pending')
    } catch (e) {
      setPhase('error')
      setError(describeError(e))
    }
  }

  return { run, phase, error, busy: phase === 'signing' || phase === 'pending' }
}
