import { Hero } from '@/components/landing/Hero'
import { HowItWorks } from '@/components/landing/HowItWorks'
import { Footnote } from '@/components/landing/Footnote'
import { landing } from '@/content/landing'

export function Landing() {
  return (
    <>
      <Hero name={landing.name} slogan={landing.slogan} description={landing.description} demo={landing.demo} />
      <HowItWorks title={landing.howItWorksTitle} steps={landing.steps} />
      <Footnote>{landing.footnote}</Footnote>
    </>
  )
}
