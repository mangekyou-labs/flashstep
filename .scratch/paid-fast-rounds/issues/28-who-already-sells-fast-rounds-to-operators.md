# Who already sells fast rounds to operators

Label: wayfinder:research
Type: research
Status: closed
Blocked by: none
Assignee: MrSufferer

## Question

Who already sells sub-minute prediction or micro-betting rounds to operators, what do they charge, and where is the gap?

Cover: Simplebet (and its DraftKings acquisition), Betgames and other live-dealer number games, crash and "up/down" games from casino providers, Pumpcade, Limitless and Polymarket short markets, Twitch and Kick prediction tools, and anything else found. For each: who pays them, the format and Window length, the settlement source, pricing if published, and traction. End with the gaps a solo dev could fill, and any that look closed.

## Resolution

No one found sells an automatic 30-second Round to operators as a B2B product. The shortest B2B formats are crash games (rounds of roughly 8-30 seconds, house-banked RNG, sold by licence; Spribe's Aviator reaches thousands of operators, price unpublished) and Betgames Lucky 6 (a 4-minute live-studio draw). Crypto up/down at 5-15 minutes (Polymarket, Limitless, Kalshi) sells to bettors, not operators; Polymarket settles on a 60-second Chainlink TWAP and runs a builder-fee programme (read only in secondary guides). Simplebet is sports-only micromarket pricing sold to sportsbooks, mostly DraftKings (10-K total consideration about $134.6m, read through a search summary). Twitch and Kick predictions are free, points-only and settled by hand. Pumpcade (60 seconds to 30 minutes, parimutuel) is the closest competitor; its mainnet status is unconfirmed and pumpcade.com showed an expired-domain page.

Looks closed (inference): crash-style house-banked games, 5-15 minute crypto up/down, sports micromarket pricing. Looks open (inference): sub-minute automatic settlement, Rounds on events beyond coin price, sponsor-funded prize Rounds, and a drop-in embed or API.

Unverified: Twitch API limits, Kick's minimum voting period, Spribe and Betgames pricing, the Polymarket builder-code page, and the Simplebet 10-K figures (not opened directly).

Details and sources: [research/28-who-already-sells-fast-rounds-to-operators.md](../research/28-who-already-sells-fast-rounds-to-operators.md)
