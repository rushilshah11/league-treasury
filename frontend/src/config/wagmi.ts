import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { anvil } from 'wagmi/chains'

// For now the app only talks to the local Anvil chain (chain id 31337).
// Base Sepolia gets added here in Milestone 5.
export const wagmiConfig = getDefaultConfig({
  appName: 'League Treasury',
  // Only needed for WalletConnect (mobile wallets). Browser wallets like MetaMask
  // work without it. Get a free id at https://cloud.reown.com when you need it.
  projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ?? 'local-dev',
  chains: [anvil],
})
