import { ConnectWallet } from '@/components/ConnectWallet'
import { Text } from '@/components/typography'

/** Shown in place of a page's content until a wallet is connected. */
export function ConnectPrompt({ children }: { children: string }) {
  return (
    <div className="flex flex-col items-start gap-5 py-6">
      <Text variant="lead">{children}</Text>
      <ConnectWallet />
    </div>
  )
}
