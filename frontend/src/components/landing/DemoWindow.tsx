import { DemoVideo } from './DemoVideo'

/** The walkthrough in a flat window frame, so it reads as the product rather than a pasted image. */
export function DemoWindow({ video, poster, label, caption }: { video: string; poster: string; label: string; caption: string }) {
  return (
    <figure className="border border-border bg-card">
      <div className="flex h-10 items-center gap-2 border-b border-border px-4">
        <span className="size-2.5 bg-primary" aria-hidden />
        <span className="size-2.5 bg-border" aria-hidden />
        <span className="size-2.5 bg-border" aria-hidden />
        <figcaption className="ml-3 text-small text-muted-foreground">{caption}</figcaption>
      </div>
      <DemoVideo src={video} poster={poster} label={label} className="border-0" />
    </figure>
  )
}
