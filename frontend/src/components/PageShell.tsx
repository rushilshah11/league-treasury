import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ConnectWallet } from '@/components/ConnectWallet'
import { DevAccountSwitcher } from '@/components/DevAccountSwitcher'
import { Container } from '@/components/layout/Container'
import { Separator } from '@/components/ui/separator'
import { Heading } from '@/components/typography'

/** Frame for every page after the landing page: wordmark, wallet, title. */
export function PageShell({
  title,
  aside,
  children,
}: {
  title: string
  /** Shown next to the title, e.g. a status badge. */
  aside?: ReactNode
  children: ReactNode
}) {
  return (
    <Container className="pb-24">
      <div className="flex flex-wrap items-center justify-between gap-4 py-6">
        <Link to="/" className="font-bold">
          On-Chain Commish
        </Link>
        <div className="flex flex-wrap items-center gap-3">
          <DevAccountSwitcher />
          <ConnectWallet />
        </div>
      </div>
      <div className="mt-10 flex flex-wrap items-center gap-4 pb-6">
        <Heading as="h1">{title}</Heading>
        {aside}
      </div>
      <Separator />
      <div className="mt-8 flex flex-col gap-12">{children}</div>
    </Container>
  )
}
