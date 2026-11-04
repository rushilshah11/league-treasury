import type { ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { ConnectWallet } from './ConnectWallet'

/** Frame for every page after the landing page: wordmark, wallet, title. */
export function PageShell({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="mx-auto max-w-6xl px-6 pb-24">
      <div className="flex items-center justify-between py-6">
        <Link to="/" className="text-[17px] font-bold">
          On-Chain Commish
        </Link>
        <ConnectWallet />
      </div>
      <h1 className="mt-10 border-b border-line pb-6 text-4xl font-bold tracking-tight">
        {title}
      </h1>
      <div className="mt-8">{children}</div>
    </div>
  )
}
