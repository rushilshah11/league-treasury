import { useEffect, useState } from 'react'
import { useBlock } from 'wagmi'

/**
 * The current time as the contract sees it, in Unix seconds.
 * Usually the wall clock, but if the local chain's clock was moved forward
 * (for testing deadlines), the latest block's timestamp wins.
 */
export function useChainNow(): number {
  const [wallClock, setWallClock] = useState(() => Math.floor(Date.now() / 1000))
  const { data: block } = useBlock({ watch: true })

  useEffect(() => {
    const id = setInterval(() => setWallClock(Math.floor(Date.now() / 1000)), 1000)
    return () => clearInterval(id)
  }, [])

  return Math.max(wallClock, Number(block?.timestamp ?? 0))
}
