import { Route, Routes } from 'react-router-dom'
import { Header } from './components/Header'

function Home() {
  return (
    <div className="space-y-2">
      <h1 className="text-2xl font-semibold">Leagues</h1>
      <p className="text-zinc-400">
        Connect your wallet to get started. League data will show up here.
      </p>
    </div>
  )
}

export default function App() {
  return (
    <>
      <Header />
      <main className="mx-auto max-w-4xl px-4 py-8">
        <Routes>
          <Route path="/" element={<Home />} />
        </Routes>
      </main>
    </>
  )
}
