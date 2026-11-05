import type { ReactNode } from 'react'
import { Card, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'

/** A card for one thing the viewer can do (or is waiting on) right now. */
export function ActionCard({
  title,
  description,
  children,
}: {
  title: string
  description: ReactNode
  children?: ReactNode
}) {
  return (
    <Card className="gap-5 border-l-4 border-l-accent">
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      {children}
    </Card>
  )
}
