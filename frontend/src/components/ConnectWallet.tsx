import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Button } from '@/components/ui/button'

/**
 * RainbowKit's wallet logic with our own shadcn Button.
 * Clicking opens RainbowKit's wallet picker.
 */
export function ConnectWallet() {
  return (
    <ConnectButton.Custom>
      {({ account, chain, mounted, openConnectModal, openAccountModal, openChainModal }) => {
        if (!mounted) return null

        if (!account || !chain) {
          return (
            <Button variant="outline" onClick={openConnectModal}>
              Connect wallet
            </Button>
          )
        }

        if (chain.unsupported) {
          return (
            <Button variant="outline" onClick={openChainModal}>
              Switch network
            </Button>
          )
        }

        return (
          <Button variant="outline" onClick={openAccountModal}>
            {account.displayName}
          </Button>
        )
      }}
    </ConnectButton.Custom>
  )
}
