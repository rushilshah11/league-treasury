import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { createConfig, http } from 'wagmi'
import { mock } from 'wagmi/connectors'
import { anvil } from 'wagmi/chains'
import { devAccounts, devWalletEnabled, getDevAccountIndex } from './devWallet'

// For now the app only talks to the local Anvil chain (chain id 31337).
// Base Sepolia gets added here in Milestone 5.

/** Normal mode: real wallets (MetaMask, etc.) through RainbowKit. */
function walletConfig() {
  return getDefaultConfig({
    appName: 'On-Chain Commish',
    // Only needed for WalletConnect (mobile wallets). Browser wallets like MetaMask
    // work without it. Get a free id at https://cloud.reown.com when you need it.
    projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID ?? 'local-dev',
    chains: [anvil],
  })
}

/** Dev wallet mode (`make dev-wallet`): act as any Anvil test account, no MetaMask needed. */
function devConfig() {
  const account = devAccounts[getDevAccountIndex()]
  return createConfig({
    chains: [anvil],
    connectors: [mock({ accounts: [account], features: { defaultConnected: true, reconnect: true } })],
    transports: { [anvil.id]: http() },
  })
}

export const wagmiConfig = devWalletEnabled ? devConfig() : walletConfig()
