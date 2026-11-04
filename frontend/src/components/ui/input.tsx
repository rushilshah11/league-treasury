import * as React from 'react'
import { Input as InputPrimitive } from '@base-ui/react/input'
import { cn } from '@/lib/utils'

// shadcn/ui Input (Base UI, lyra style).
function Input({ className, type, ...props }: React.ComponentProps<'input'>) {
  return (
    <InputPrimitive
      type={type}
      data-slot="input"
      className={cn(
        'h-11 w-full min-w-0 rounded-none border border-input bg-transparent px-3 text-body text-foreground transition-colors outline-none placeholder:text-muted-foreground focus-visible:border-ring disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive',
        className,
      )}
      {...props}
    />
  )
}

export { Input }
