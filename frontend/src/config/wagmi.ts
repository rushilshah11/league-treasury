import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { createConfig, http, type Transport } from 'wagmi'
import { mock } from 'wagmi/connectors'
import { chain, rpcUrl } from './chain'
import { devAccounts, devWalletEnabled, getDevAccountIndex } from './devWallet'

/** Normal mode: real wallets (MetaMask, etc.) through RainbowKit, on the chain from VITE_CHAIN. */
function walletConfig() {
  return getDefaultConfig({
    appName: 'On-Chain Commish',
    // Only needed for WalletConnect (mobile wallets). Browser wallets like MetaMask
    // work without it. Get a free id at https://cloud.reown.com when you need it.
    projectId: import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || 'local-dev',
    chains: [chain],
    transports: { [chain.id]: http(rpcUrl) },
  })
}

/** Dev wallet mode (`make dev-wallet`): act as any Anvil test account, no MetaMask needed. Anvil only. */
function devConfig() {
  const account = devAccounts[getDevAccountIndex()]
  return createConfig({
    chains: [chain],
    connectors: [mock({ accounts: [account], features: { defaultConnected: true, reconnect: true } })],
    // `chain` is one of several chains at compile time, so spell out the transport map's type.
    transports: { [chain.id]: http(rpcUrl) } as Record<typeof chain.id, Transport>,
  })
}

export const wagmiConfig = devWalletEnabled ? devConfig() : walletConfig()
