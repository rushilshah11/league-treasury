import * as React from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Text } from '@/components/typography'

type FormFieldProps = React.ComponentProps<typeof Input> & {
  id: string
  label: string
  hint?: string
}

/** A labelled input with optional hint text underneath. */
export function FormField({ id, label, hint, ...inputProps }: FormFieldProps) {
  return (
    <div className="flex flex-col gap-2">
      <Label htmlFor={id}>{label}</Label>
      <Input id={id} aria-describedby={hint ? `${id}-hint` : undefined} {...inputProps} />
      {hint && (
        <Text id={`${id}-hint`} variant="small">
          {hint}
        </Text>
      )}
    </div>
  )
}
