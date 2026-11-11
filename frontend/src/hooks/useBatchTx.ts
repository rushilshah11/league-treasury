import { useEffect, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useSendCalls, useWaitForCallsStatus } from 'wagmi'
import type { TransactionReceipt } from 'viem'
import { describeError } from '@/lib/errors'
import type { TxPhase } from '@/hooks/useTx'

/**
 * Like useTx, but sends several calls as one atomic batch (EIP-5792) from a wallet that supports it.
 * If any call fails, none of them happen, so a stray approval can't be left behind.
 * idle -> signing -> pending -> success | error. On success every cached chain read refreshes.
 */
export function useBatchTx(onSuccess?: (receipt: TransactionReceipt) => void) {
  const { sendCallsAsync } = useSendCalls()
  const queryClient = useQueryClient()
  const [id, setId] = useState<string>()
  const [phase, setPhase] = useState<TxPhase>('idle')
  const [error, setError] = useState<string>()
  const status = useWaitForCallsStatus({ id, query: { enabled: id !== undefined } })

  useEffect(() => {
    if (!id || phase !== 'pending') return
    if (status.data?.status === 'success') {
      const receipt = status.data.receipts?.[0]
      setPhase('success')
      queryClient.invalidateQueries()
      if (receipt) onSuccess?.(receipt as unknown as TransactionReceipt)
    } else if (status.data?.status === 'failure') {
      setPhase('error')
      setError('The transaction was reverted.')
    } else if (status.isError) {
      setPhase('error')
      setError(describeError(status.error))
    }
  }, [id, phase, status.data, status.isError, status.error, queryClient, onSuccess])

  async function run(send: (sendCalls: typeof sendCallsAsync) => Promise<{ id: string }>) {
    setPhase('signing')
    setError(undefined)
    try {
      setId((await send(sendCallsAsync)).id)
      setPhase('pending')
    } catch (e) {
      setPhase('error')
      setError(describeError(e))
    }
  }

  return { run, phase, error, busy: phase === 'signing' || phase === 'pending' }
}
