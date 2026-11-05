import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

// shadcn/ui Alert (lyra style).
const alertVariants = cva('grid gap-1 rounded-none border px-4 py-3 text-left text-body', {
  variants: {
    variant: {
      default: 'bg-card text-card-foreground',
      destructive: 'border-destructive/40 bg-destructive/10 text-destructive',
      success: 'border-primary/40 bg-primary/10 text-foreground',
    },
  },
  defaultVariants: { variant: 'default' },
})

function Alert({ className, variant, ...props }: React.ComponentProps<'div'> & VariantProps<typeof alertVariants>) {
  return <div data-slot="alert" role="alert" className={cn(alertVariants({ variant }), className)} {...props} />
}

function AlertTitle({ className, ...props }: React.ComponentProps<'div'>) {
  return <div data-slot="alert-title" className={cn('font-bold', className)} {...props} />
}

function AlertDescription({ className, ...props }: React.ComponentProps<'div'>) {
  return <div data-slot="alert-description" className={cn('text-muted-foreground', className)} {...props} />
}

export { Alert, AlertTitle, AlertDescription }
