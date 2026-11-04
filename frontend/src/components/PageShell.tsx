import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ConnectWallet } from '@/components/ConnectWallet'
import { Container } from '@/components/layout/Container'
import { Separator } from '@/components/ui/separator'
import { Heading } from '@/components/typography'

/** Frame for every page after the landing page: wordmark, wallet, title. */
export function PageShell({ title, children }: { title: string; children: ReactNode }) {
  return (
    <Container className="pb-24">
      <div className="flex items-center justify-between py-6">
        <Link to="/" className="font-bold">
          On-Chain Commish
        </Link>
        <ConnectWallet />
      </div>
      <Heading as="h1" className="mt-10 pb-6">
        {title}
      </Heading>
      <Separator />
      <div className="mt-8">{children}</div>
    </Container>
  )
}
