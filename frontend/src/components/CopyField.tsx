import { useState } from 'react'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

/** A read-only value with a copy button, e.g. an invite link. */
export function CopyField({ id, label, value }: { id: string; label: string; value: string }) {
  const [copied, setCopied] = useState(false)

  async function copy() {
    try {
      await navigator.clipboard.writeText(value)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // clipboard blocked: the field is still selectable by hand
    }
  }

  return (
    <div className="flex flex-col gap-2">
      <Label htmlFor={id}>{label}</Label>
      <div className="flex gap-2">
        <Input id={id} readOnly value={value} onFocus={(e) => e.currentTarget.select()} />
        <Button variant="outline" onClick={copy} className="w-28">
          {copied ? 'Copied' : 'Copy'}
        </Button>
      </div>
    </div>
  )
}
