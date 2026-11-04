import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const containerVariants = cva('mx-auto w-full px-6', {
  variants: {
    width: {
      narrow: 'max-w-2xl',
      wide: 'max-w-6xl',
    },
  },
  defaultVariants: { width: 'wide' },
})

type ContainerProps = React.ComponentProps<'div'> & VariantProps<typeof containerVariants>

/** Centers content and keeps it at a readable width. */
export function Container({ width, className, ...props }: ContainerProps) {
  return <div className={cn(containerVariants({ width }), className)} {...props} />
}
