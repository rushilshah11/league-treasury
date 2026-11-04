import { ButtonLink } from '../Button'

type HeroProps = {
  name: string
  slogan: string
  description: string
}

export function Hero({ name, slogan, description }: HeroProps) {
  return (
    <section className="flex flex-col items-center px-6 pt-32 pb-24 text-center sm:pt-40">
      <h1 className="text-6xl font-bold tracking-tight sm:text-8xl">{name}</h1>
      <p className="mt-6 text-2xl font-bold text-flare sm:text-3xl">{slogan}</p>
      <p className="mt-6 max-w-[48ch] text-lg leading-relaxed text-dust">{description}</p>
      <div className="mt-10 flex flex-wrap justify-center gap-3">
        <ButtonLink to="/create">Create a league</ButtonLink>
        <ButtonLink to="/leagues" variant="secondary">
          My leagues
        </ButtonLink>
      </div>
    </section>
  )
}
