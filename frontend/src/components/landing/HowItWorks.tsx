import { StepCard } from './StepCard'

type HowItWorksProps = {
  title: string
  steps: ReadonlyArray<{ title: string; body: string }>
}

export function HowItWorks({ title, steps }: HowItWorksProps) {
  return (
    <section className="mx-auto max-w-2xl px-6 pb-24">
      <h2 className="text-center text-3xl font-bold tracking-tight">{title}</h2>
      <ol className="mt-10 flex flex-col gap-5">
        {steps.map((step, i) => (
          <StepCard key={step.title} number={i + 1} title={step.title} body={step.body} />
        ))}
      </ol>
    </section>
  )
}
