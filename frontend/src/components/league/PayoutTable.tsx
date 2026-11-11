import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { formatUsdc } from '@/lib/format'
import { formatBps, payoutAmounts } from '@/lib/payouts'

/** How the pot is split by finishing place. */
export function PayoutTable({ payoutBps, pot }: { payoutBps: number[]; pot: bigint }) {
  const amounts = payoutAmounts(pot, payoutBps)
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Place</TableHead>
          <TableHead className="text-right">Share</TableHead>
          <TableHead className="text-right">Payout</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {payoutBps.map((bps, i) => (
          <TableRow key={i}>
            <TableCell className="font-bold">{i + 1}</TableCell>
            <TableCell className="text-right">{formatBps(bps)}</TableCell>
            <TableCell className="text-right">{formatUsdc(amounts[i])}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
