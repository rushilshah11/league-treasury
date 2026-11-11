import path from 'node:path'
import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { espnMiddleware } from './server/espn.mjs'

/** Serves /api/espn/:leagueId from the local dev server, so the browser never calls ESPN directly. */
function espnApi(): Plugin {
  return {
    name: 'espn-api',
    configureServer: (server) => void server.middlewares.use(espnMiddleware),
    configurePreviewServer: (server) => void server.middlewares.use(espnMiddleware),
  }
}

// https://vite.dev/config/
export default defineConfig({
  // Vite only exposes VITE_* variables to the browser. RPC_URL is also exposed, so it can be saved on
  // Vercel under that name. It ends up in the site's JavaScript either way: restrict the key to your
  // domain in Alchemy. Never put a private key in either variable.
  envPrefix: ['VITE_', 'RPC_URL'],
  plugins: [react(), tailwindcss(), espnApi()],
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
})
