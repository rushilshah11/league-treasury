import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Button } from './Button'

/**
 * RainbowKit's wallet logic with our own square, on-brand button.
 * Clicking opens RainbowKit's wallet picker.
 */
export function ConnectWallet() {
  return (
    <ConnectButton.Custom>
      {({ account, chain, mounted, openConnectModal, openAccountModal, openChainModal }) => {
        if (!mounted) return null

        if (!account || !chain) {
          return (
            <Button variant="secondary" onClick={openConnectModal}>
              Connect wallet
            </Button>
          )
        }

        if (chain.unsupported) {
          return (
            <Button variant="secondary" onClick={openChainModal}>
              Switch network
            </Button>
          )
        }

        return (
          <Button variant="secondary" onClick={openAccountModal}>
            {account.displayName}
          </Button>
        )
      }}
    </ConnectButton.Custom>
  )
}
