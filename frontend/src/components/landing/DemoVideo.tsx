import { useEffect, useRef, useState } from 'react'
import { cn } from '@/lib/utils'

type DemoVideoProps = {
  src: string
  poster: string
  /** Describes the video for screen readers. */
  label: string
  className?: string
}

/**
 * The product walkthrough. Plays silently on a loop, like a moving screenshot.
 * For people who prefer reduced motion it stays on the poster with play controls.
 */
export function DemoVideo({ src, poster, label, className }: DemoVideoProps) {
  const ref = useRef<HTMLVideoElement>(null)
  const [reducedMotion, setReducedMotion] = useState(false)

  useEffect(() => {
    const query = window.matchMedia('(prefers-reduced-motion: reduce)')
    const update = () => setReducedMotion(query.matches)
    update()
    query.addEventListener('change', update)
    return () => query.removeEventListener('change', update)
  }, [])

  useEffect(() => {
    const video = ref.current
    if (!video) return
    if (reducedMotion) video.pause()
    else video.play().catch(() => {}) // autoplay can be blocked; the poster still shows
  }, [reducedMotion])

  return (
    <video
      ref={ref}
      src={src}
      poster={poster}
      aria-label={label}
      muted
      loop
      playsInline
      autoPlay={!reducedMotion}
      controls={reducedMotion}
      preload="metadata"
      className={cn('aspect-video w-full border border-border bg-card', className)}
    />
  )
}
