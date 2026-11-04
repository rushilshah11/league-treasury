import { Card, CardDescription, CardTitle } from '@/components/ui/card'

type StepCardProps = {
  number: number
  title: string
  body: string
}

/** One step of the season, as a standalone card. */
export function StepCard({ number, title, body }: StepCardProps) {
  return (
    <li>
      <Card className="flex-row gap-6 border-l-4 border-l-accent">
        <span className="text-title leading-none font-bold text-primary">{number}</span>
        <div className="flex flex-col gap-2">
          <CardTitle>{title}</CardTitle>
          <CardDescription>{body}</CardDescription>
        </div>
      </Card>
    </li>
  )
}
