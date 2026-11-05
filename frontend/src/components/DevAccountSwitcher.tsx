import { devAccounts, devWalletEnabled, getDevAccountIndex, setDevAccountIndex } from '@/config/devWallet'
import { shortAddress } from '@/lib/format'

/** LOCAL DEVELOPMENT ONLY: switch which Anvil test account the app acts as. */
export function DevAccountSwitcher() {
  if (!devWalletEnabled) return null
  return (
    <label className="flex items-center gap-2 text-small text-muted-foreground">
      <span className="hidden sm:inline">Dev account</span>
      <select
        aria-label="Dev account"
        className="h-11 rounded-none border border-input bg-background px-2 text-body text-foreground"
        value={getDevAccountIndex()}
        onChange={(e) => setDevAccountIndex(Number(e.target.value))}
      >
        {devAccounts.map((address, i) => (
          <option key={address} value={i}>
            {i}: {shortAddress(address)}
          </option>
        ))}
      </select>
    </label>
  )
}
