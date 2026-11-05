import * as React from 'react'
import { Label } from '@/components/ui/label'
import { NativeSelect } from '@/components/ui/native-select'
import { Text } from '@/components/typography'

type SelectFieldProps = React.ComponentProps<typeof NativeSelect> & {
  id: string
  label: string
  hint?: string
}

/** A labelled dropdown with optional hint text, matching FormField. */
export function SelectField({ id, label, hint, children, ...selectProps }: SelectFieldProps) {
  return (
    <div className="flex flex-col gap-2">
      <Label htmlFor={id}>{label}</Label>
      <NativeSelect id={id} aria-describedby={hint ? `${id}-hint` : undefined} {...selectProps}>
        {children}
      </NativeSelect>
      {hint && (
        <Text id={`${id}-hint`} variant="small">
          {hint}
        </Text>
      )}
    </div>
  )
}
