import { Container } from '@/components/layout/Container'
import { Heading } from '@/components/typography'
import { StepCard } from './StepCard'

type HowItWorksProps = {
  title: string
  steps: ReadonlyArray<{ title: string; body: string }>
}

export function HowItWorks({ title, steps }: HowItWorksProps) {
  return (
    <Container width="narrow" className="pb-24">
      <Heading className="text-center">{title}</Heading>
      <ol className="mt-10 flex flex-col gap-5">
        {steps.map((step, i) => (
          <StepCard key={step.title} number={i + 1} title={step.title} body={step.body} />
        ))}
      </ol>
    </Container>
  )
}
