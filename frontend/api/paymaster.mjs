// Vercel Function: forwards a wallet's gas-sponsorship requests to the Coinbase (CDP) paymaster.
// The paymaster URL contains an API key, so it lives in the CDP_PAYMASTER_URL environment variable
// on Vercel (a normal variable, not VITE_) and never reaches the browser.
//
// Only the paymaster's own JSON-RPC methods are forwarded. Which contracts get sponsored is set in the
// CDP dashboard's allowlist (the treasury and the USDC token), which is what limits what this can pay for.
const ALLOWED_METHODS = new Set(['pm_getPaymasterStubData', 'pm_getPaymasterData', 'pm_sponsorUserOperation'])

export async function POST(request) {
  const url = process.env.CDP_PAYMASTER_URL
  if (!url) return Response.json({ error: 'Gas sponsorship is not set up.' }, { status: 503 })

  let body
  try {
    body = await request.json()
  } catch {
    return Response.json({ error: 'Send a JSON-RPC request.' }, { status: 400 })
  }
  if (!ALLOWED_METHODS.has(body?.method)) {
    return Response.json({ error: 'That method is not supported.' }, { status: 400 })
  }

  const upstream = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  return new Response(await upstream.text(), {
    status: upstream.status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  })
}
