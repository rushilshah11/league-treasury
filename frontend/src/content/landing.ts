export const landing = {
  name: 'On-Chain Commish',
  slogan: 'The commissioner every fantasy league can trust.',
  description:
    "Your fantasy league's buy-ins are held by code until the season ends, then paid out by final standings. Every team gets something back.",
  demo: {
    video: '/demo/walkthrough.mp4',
    poster: '/demo/walkthrough-poster.jpg',
    caption: 'A full season, start to payout',
    label: 'A full season in On-Chain Commish: create a league, managers join, live ESPN standings, final standings posted, payouts claimed.',
  },
  footnote: 'Funds are held by an open-source smart contract. Test network only, no real money.',
  howItWorksTitle: 'How a season works',
  steps: [
    {
      title: 'Create a league',
      body: 'Set the buy-in, the number of teams and the deadlines. You get an invite link to share.',
    },
    {
      title: 'Everyone pays in',
      body: 'Members open the link, connect a wallet and pay the buy-in. The money sits in a smart contract that no one can touch, including you.',
    },
    {
      title: 'Settle at season end',
      body: 'Final standings come straight from ESPN. After a 48-hour window to dispute them, every team claims its share.',
    },
  ],
} as const
