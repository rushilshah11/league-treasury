import type { VariantProps } from 'class-variance-authority'
import { Link, type LinkProps } from 'react-router-dom'
import { buttonVariants } from '@/components/ui/button'
import { cn } from '@/lib/utils'

/** A router link that looks like a Button. */
export function ButtonLink({
  className,
  variant,
  size,
  ...props
}: LinkProps & VariantProps<typeof buttonVariants>) {
  return <Link className={cn(buttonVariants({ variant, size }), className)} {...props} />
}
