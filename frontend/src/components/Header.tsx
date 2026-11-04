import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Link } from 'react-router-dom'

export function Header() {
  return (
    <header className="border-b border-zinc-800">
      <div className="mx-auto flex max-w-4xl items-center justify-between px-4 py-4">
        <Link to="/" className="text-lg font-semibold tracking-tight">
          League Treasury
        </Link>
        <ConnectButton />
      </div>
    </header>
  )
}
