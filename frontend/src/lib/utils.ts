import { clsx, type ClassValue } from 'clsx'
import { extendTailwindMerge } from 'tailwind-merge'

// Teach tailwind-merge about our custom type scale (see index.css). Without this it
// mistakes `text-lead` for a text color and drops it when combined with `text-primary`.
const twMerge = extendTailwindMerge({
  extend: {
    classGroups: {
      'font-size': [{ text: ['display', 'title', 'tagline', 'heading', 'lead', 'body', 'small'] }],
    },
  },
})

/** Merge class names, letting later Tailwind classes override earlier ones. */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
