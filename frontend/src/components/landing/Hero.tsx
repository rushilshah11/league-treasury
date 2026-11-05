import { ButtonLink } from '@/components/ButtonLink'
import { Container } from '@/components/layout/Container'
import { Heading, Text } from '@/components/typography'
import { DemoWindow } from './DemoWindow'

type HeroProps = {
  name: string
  slogan: string
  description: string
  demo: { video: string; poster: string; label: string; caption: string }
}

/** Split hero: the pitch on the left, the product in motion on the right. Stacks on phones. */
export function Hero({ name, slogan, description, demo }: HeroProps) {
  return (
    <section className="pt-16 pb-24 sm:pt-24">
      <Container className="grid items-center gap-12 lg:grid-cols-[5fr_7fr] lg:gap-16">
        <div className="flex flex-col items-start gap-6">
          <Heading as="h1" size="display">
            {name}
          </Heading>
          <Text variant="tagline">{slogan}</Text>
          <Text variant="lead" className="max-w-[44ch]">
            {description}
          </Text>
          <div className="mt-2 flex flex-wrap gap-3">
            <ButtonLink to="/create" size="lg">
              Create a league
            </ButtonLink>
            <ButtonLink to="/leagues" size="lg" variant="outline">
              My leagues
            </ButtonLink>
          </div>
        </div>
        <DemoWindow {...demo} />
      </Container>
    </section>
  )
}
