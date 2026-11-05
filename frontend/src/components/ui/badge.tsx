import { mergeProps } from '@base-ui/react/merge-props'
import { useRender } from '@base-ui/react/use-render'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

// shadcn/ui Badge (Base UI, lyra style).
const badgeVariants = cva(
  'inline-flex h-7 w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-none border border-transparent px-2.5 text-small font-bold whitespace-nowrap',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground',
        secondary: 'bg-secondary text-secondary-foreground',
        destructive: 'bg-destructive/15 text-destructive',
        outline: 'border-border text-foreground',
        muted: 'border-border text-muted-foreground',
      },
    },
    defaultVariants: { variant: 'default' },
  },
)

function Badge({
  className,
  variant = 'default',
  render,
  ...props
}: useRender.ComponentProps<'span'> & VariantProps<typeof badgeVariants>) {
  return useRender({
    defaultTagName: 'span',
    props: mergeProps<'span'>({ className: cn(badgeVariants({ variant }), className) }, props),
    render,
    state: { slot: 'badge', variant },
  })
}

export { Badge, badgeVariants }
