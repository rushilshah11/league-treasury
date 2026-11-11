import { anvil, baseSepolia, sepolia } from 'wagmi/chains'

/**
 * Which network the app talks to, from VITE_CHAIN:
 *   anvil   (default) the local chain from `make anvil`
 *   sepolia Ethereum's Sepolia testnet
 *   base-sepolia Base's Sepolia testnet (an L2, much cheaper gas)
 */
const CHAINS = { anvil, sepolia, 'base-sepolia': baseSepolia } as const
type ChainName = keyof typeof CHAINS

// `||`, not `??`: a blank line like `VITE_CHAIN=` in a .env file counts as unset.
const name = (import.meta.env.VITE_CHAIN || 'anvil') as ChainName
if (!(name in CHAINS)) throw new Error(`Unknown VITE_CHAIN "${name}". Use "anvil", "sepolia" or "base-sepolia".`)

export const chain = CHAINS[name]
export const isLocalChain = chain.id === anvil.id

/** RPC endpoint, from VITE_RPC_URL or RPC_URL. Optional: each chain has a public default, but a free Alchemy or Infura URL is more reliable. */
export const rpcUrl = import.meta.env.VITE_RPC_URL || import.meta.env.RPC_URL || undefined
