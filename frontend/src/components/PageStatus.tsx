import { Text } from '@/components/typography'

/** Placeholder text for loading, empty and not-found states. */
export function PageStatus({ children }: { children: string }) {
  return (
    <Text variant="lead" className="py-10">
      {children}
    </Text>
  )
}
