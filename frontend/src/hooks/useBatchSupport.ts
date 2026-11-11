import { useAccount, useCapabilities } from 'wagmi'
import { chain } from '@/config/chain'

/**
 * Set VITE_PAYMASTER=on once the paymaster proxy (api/paymaster.mjs) is configured, so
 * smart wallets get their gas sponsored. Off by default: without it a smart wallet pays its own gas.
 */
const PAYMASTER_ON = import.meta.env.VITE_PAYMASTER === 'on'

/**
 * Whether the connected wallet can run several calls as one atomic transaction (EIP-5792),
 * so "approve USDC, then pay" becomes a single step. Smart wallets like Base Account can.
 *
 * Only a wallet that reports atomic batching as `supported` counts. MetaMask reports `ready` for
 * accounts it could upgrade, and that would trigger an account-upgrade prompt, so those keep the
 * normal two-step flow.
 */
export function useBatchSupport() {
  const { address } = useAccount()
  const { data } = useCapabilities({ account: address, chainId: chain.id, query: { enabled: address !== undefined } })

  const canBatch = data?.atomic?.status === 'supported'
  const sponsored = canBatch && PAYMASTER_ON && data?.paymasterService?.supported === true
  return {
    canBatch,
    /** Capabilities to pass to sendCalls: the gas sponsor, when the wallet supports it and it's switched on. */
    capabilities: sponsored ? { paymasterService: { url: `${window.location.origin}/api/paymaster` } } : undefined,
  }
}
