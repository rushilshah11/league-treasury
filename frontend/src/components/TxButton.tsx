import type { ComponentProps } from 'react'
import { Button } from '@/components/ui/button'
import { Alert, AlertDescription } from '@/components/ui/alert'
import type { TxPhase } from '@/hooks/useTx'

type TxButtonProps = ComponentProps<typeof Button> & {
  phase: TxPhase
  error?: string
  /** What the button does, e.g. "Join league". */
  label: string
  /** Shown while the transaction is confirming, e.g. "Joining…". */
  pendingLabel: string
}

/** A button that sends a transaction and shows each stage of it. */
export function TxButton({ phase, error, label, pendingLabel, disabled, ...props }: TxButtonProps) {
  const text = phase === 'signing' ? 'Confirm in your wallet…' : phase === 'pending' ? pendingLabel : label
  return (
    <div className="flex flex-col items-start gap-3">
      <Button size="lg" disabled={disabled || phase === 'signing' || phase === 'pending'} {...props}>
        {text}
      </Button>
      {phase === 'error' && error && (
        <Alert variant="destructive">
          <AlertDescription className="text-destructive">{error}</AlertDescription>
        </Alert>
      )}
    </div>
  )
}
