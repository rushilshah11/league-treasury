import type { ReactNode } from 'react'

/** A labelled value, e.g. "Pot / 0.14 ETH". */
export function Stat({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex flex-col gap-1 border-t pt-3">
      <dt className="text-small text-muted-foreground">{label}</dt>
      <dd className="text-heading font-bold">{value}</dd>
    </div>
  )
}

export function StatGrid({ children }: { children: ReactNode }) {
  return <dl className="grid grid-cols-2 gap-6 md:grid-cols-4">{children}</dl>
}
