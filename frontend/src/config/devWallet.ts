import { mnemonicToAccount } from 'viem/accounts'
import type { Address } from 'viem'
import { isLocalChain } from './chain'

/**
 * LOCAL DEVELOPMENT ONLY.
 * Anvil's built-in test accounts, derived from Anvil's public default mnemonic.
 * They're unlocked on a local Anvil chain, so the app can act as any of them
 * without MetaMask. Never use these anywhere but a local chain.
 */
const ANVIL_MNEMONIC = 'test test test test test test test test test test test junk'
export const DEV_ACCOUNT_COUNT = 20
const STORAGE_KEY = 'commish.devAccount'

// Never on a real network: these keys are public.
export const devWalletEnabled = import.meta.env.VITE_DEV_WALLET === 'true' && isLocalChain

export const devAccounts: Address[] = devWalletEnabled
  ? Array.from({ length: DEV_ACCOUNT_COUNT }, (_, i) => mnemonicToAccount(ANVIL_MNEMONIC, { addressIndex: i }).address)
  : []

/** Which Anvil account the dev wallet acts as. `?as=3` in the URL overrides it. */
export function getDevAccountIndex(): number {
  try {
    const fromUrl = new URLSearchParams(window.location.search).get('as')
    if (fromUrl !== null) localStorage.setItem(STORAGE_KEY, fromUrl)
    const index = Number(localStorage.getItem(STORAGE_KEY) ?? 0)
    return Number.isInteger(index) && index >= 0 && index < DEV_ACCOUNT_COUNT ? index : 0
  } catch {
    return 0
  }
}

export function setDevAccountIndex(index: number) {
  try {
    localStorage.setItem(STORAGE_KEY, String(index))
  } catch {
    // storage unavailable: the switch lasts until reload
  }
  const url = new URL(window.location.href)
  url.searchParams.delete('as')
  window.location.replace(url.toString())
}
