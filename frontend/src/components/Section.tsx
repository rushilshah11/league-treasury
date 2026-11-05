import type { ReactNode } from 'react'
import { Heading } from '@/components/typography'

/** A titled block within a page. */
export function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="flex flex-col gap-5">
      <Heading as="h2" size="heading">
        {title}
      </Heading>
      {children}
    </section>
  )
}
