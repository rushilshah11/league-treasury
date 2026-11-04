import * as React from 'react'
import { cn } from '@/lib/utils'

// shadcn/ui Label (lyra style).
function Label({ className, ...props }: React.ComponentProps<'label'>) {
  return (
    <label
      data-slot="label"
      className={cn('flex items-center gap-2 text-small font-bold select-none peer-disabled:opacity-50', className)}
      {...props}
    />
  )
}

export { Label }
