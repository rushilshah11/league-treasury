/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_TREASURY_ADDRESS?: `0x${string}`
  readonly VITE_WALLETCONNECT_PROJECT_ID?: string
}
