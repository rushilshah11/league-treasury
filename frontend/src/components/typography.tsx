import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

/*
  Text styles as components, so pages say <Heading size="title"> instead of
  repeating size, weight and spacing classes everywhere.
*/

const headingVariants = cva('font-bold text-foreground', {
  variants: {
    size: {
      display: 'text-display',
      title: 'text-title',
      heading: 'text-heading',
    },
  },
  defaultVariants: { size: 'title' },
})

type HeadingProps = React.ComponentProps<'h1'> &
  VariantProps<typeof headingVariants> & { as?: 'h1' | 'h2' | 'h3' }

export function Heading({ as: Tag = 'h2', size, className, ...props }: HeadingProps) {
  return <Tag className={cn(headingVariants({ size }), className)} {...props} />
}

const textVariants = cva('', {
  variants: {
    variant: {
      tagline: 'text-tagline font-bold text-primary',
      lead: 'text-lead text-muted-foreground',
      body: 'text-body text-foreground',
      muted: 'text-body text-muted-foreground',
      small: 'text-small text-muted-foreground',
    },
    measure: {
      none: '',
      readable: 'max-w-[48ch]',
    },
  },
  defaultVariants: { variant: 'body', measure: 'none' },
})

type TextProps = React.ComponentProps<'p'> & VariantProps<typeof textVariants>

export function Text({ variant, measure, className, ...props }: TextProps) {
  return <p className={cn(textVariants({ variant, measure }), className)} {...props} />
}
