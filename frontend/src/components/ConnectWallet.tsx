import { ConnectButton } from '@rainbow-me/rainbowkit'
import { erc20Abi, type Address } from 'viem'
import { useReadContract } from 'wagmi'
import { Button } from '@/components/ui/button'
import { useUsdc } from '@/hooks/useUsdc'
import { formatUsdc } from '@/lib/format'

/** The wallet button's label: the address, plus the wallet's USDC balance once it has loaded. */
function AccountLabel({ address, displayName }: { address: Address; displayName: string }) {
  const { usdc } = useUsdc()
  const { data: balance } = useReadContract({
    address: usdc?.address,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address],
    query: { enabled: usdc !== undefined },
  })
  return (
    <>
      {balance !== undefined && <span className="text-muted-foreground">{formatUsdc(balance)} USDC</span>}
      <span>{displayName}</span>
    </>
  )
}

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
            <AccountLabel address={account.address as Address} displayName={account.displayName} />
          </Button>
        )
      }}
    </ConnectButton.Custom>
  )
}
