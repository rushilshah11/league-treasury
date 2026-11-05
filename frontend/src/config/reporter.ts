import type { Address } from 'viem'

/**
 * The standings bot's wallet. Every league uses it as its reporter, so no
 * commissioner can pick a reporter they control.
 *
 * Production: set VITE_REPORTER_ADDRESS to the bot's own wallet (a fresh one used
 * only by the bot; its private key lives with the bot, never in this app).
 * Locally it defaults to Anvil account 19, which `make report` signs as.
 */
const ANVIL_ACCOUNT_19: Address = '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199'

export const REPORTER_ADDRESS: Address =
  (import.meta.env.VITE_REPORTER_ADDRESS as Address | undefined) ?? ANVIL_ACCOUNT_19
