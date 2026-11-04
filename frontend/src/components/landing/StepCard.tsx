type StepCardProps = {
  number: number
  title: string
  body: string
}

/** One step of the season, as a standalone panel. */
export function StepCard({ number, title, body }: StepCardProps) {
  return (
    <li className="flex gap-6 border border-line border-l-4 border-l-ember bg-panel p-7">
      <span className="text-4xl leading-none font-bold text-flare">{number}</span>
      <div>
        <h3 className="text-xl font-bold">{title}</h3>
        <p className="mt-2 leading-relaxed text-dust">{body}</p>
      </div>
    </li>
  )
}
