import { Container } from '@/components/layout/Container'
import { Separator } from '@/components/ui/separator'
import { Text } from '@/components/typography'

export function Footnote({ children }: { children: string }) {
  return (
    <Container width="narrow">
      <Separator />
      <Text variant="small" className="py-8 text-center">
        {children}
      </Text>
    </Container>
  )
}
