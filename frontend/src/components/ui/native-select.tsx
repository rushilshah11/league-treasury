import * as React from 'react'
import { cn } from '@/lib/utils'

// shadcn/ui NativeSelect (lyra style): a styled <select>, matching Input.
function NativeSelect({ className, ...props }: React.ComponentProps<'select'>) {
  return (
    <select
      data-slot="native-select"
      className={cn(
        'h-11 w-full min-w-0 rounded-none border border-input bg-background px-3 text-body text-foreground transition-colors outline-none focus-visible:border-ring disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive',
        className,
      )}
      {...props}
    />
  )
}

export { NativeSelect }
