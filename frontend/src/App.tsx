import { Route, Routes } from 'react-router-dom'
import { Landing } from './pages/Landing'
import { CreateLeague } from './pages/CreateLeague'
import { MyLeagues } from './pages/MyLeagues'
import { LeaguePage } from './pages/LeaguePage'
import { JoinLeague } from './pages/JoinLeague'

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/create" element={<CreateLeague />} />
      <Route path="/leagues" element={<MyLeagues />} />
      <Route path="/league/:leagueId" element={<LeaguePage />} />
      <Route path="/league/:leagueId/join" element={<JoinLeague />} />
    </Routes>
  )
}
