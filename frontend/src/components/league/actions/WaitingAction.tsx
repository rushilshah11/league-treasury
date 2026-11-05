import { ActionCard } from '../ActionCard'

/** Nothing for the viewer to do right now; explains what the league is waiting on. */
export function WaitingAction({ title, description }: { title: string; description: string }) {
  return <ActionCard title={title} description={description} />
}
