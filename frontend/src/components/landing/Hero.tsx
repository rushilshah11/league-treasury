import { ButtonLink } from '@/components/ButtonLink'
import { Heading, Text } from '@/components/typography'

type HeroProps = {
  name: string
  slogan: string
  description: string
}

export function Hero({ name, slogan, description }: HeroProps) {
  return (
    <section className="flex flex-col items-center gap-6 px-6 pt-32 pb-24 text-center sm:pt-40">
      <Heading as="h1" size="display">
        {name}
      </Heading>
      <Text variant="tagline">{slogan}</Text>
      <Text variant="lead" measure="readable">
        {description}
      </Text>
      <div className="mt-4 flex flex-wrap justify-center gap-3">
        <ButtonLink to="/create" size="lg">
          Create a league
        </ButtonLink>
        <ButtonLink to="/leagues" size="lg" variant="outline">
          My leagues
        </ButtonLink>
      </div>
    </section>
  )
}
