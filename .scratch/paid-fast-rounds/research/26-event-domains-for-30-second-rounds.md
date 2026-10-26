# Event domains for 30-second Rounds

Research for ticket 26 (`../issues/26-which-events-settle-in-30-seconds-without-a-person.md`). Not legal advice. Date: 2026-10-26.

Labels: **sourced** = stated by a first-party page or doc I fetched; **sourced (secondary)** = a search result, news item or third-party write-up of a primary source I could not open or read in full; **inferred** = my reasoning.

Builds on `.scratch/creator-feed-markets/research/11-feed-settlement-for-fast-markets.md` (price feeds, sports API tiers, Pumpcade, attack table, outage and tie rules). Those findings are not repeated unless they change. Note: ticket 12 (window and stake design) is closed as superseded and holds no design to inherit; I used note 11's rules (hard Cutoff, pinned read time, void and refund on outage) as the baseline.

## Summary

- **Only two kinds of domain fit a solo dev with $0 and no human: events the chain itself produces, and public randomness.** Everything that needs a real-world feed (sports, esports, livestream, social) either costs real money, bars betting use, or has no latency guarantee (mix of sourced and inferred, details below).
- **Ranking for a solo dev with $0 (best first):** 1. onchain events on Base (blocks, gas, logs); 2. public randomness rounds (drand/VRF; these are "event-free"); 3. Farcaster social counts (free tier, but delayed and easy to fake); 4. Twitch livestream events (free API, terms unverified, streamer can cause the outcome); 5. esports; 6. sports. Crypto prices (already covered in note 11) stay the baseline and are not re-ranked here.
- **Licence is the wall for sports and esports.** PandaScore's stats plans are "only available to customers with non betting-related usage"; Live Basic starts at 1,000 EUR per game per month (sourced). Riot's policy says "Your product cannot feature betting or gambling functionality" (sourced). Sportradar's US terms reportedly bar gambling use without written approval (sourced, secondary; I could not open the clause). A betting operator buys these through enterprise deals; a $0 solo dev cannot (inferred).
- **Manipulation matters more than latency.** In 30 seconds the cheapest attack is usually the bettor or the event's own actor (a streamer, a poster, a block builder) causing the outcome. Polymarket changed its 5-minute crypto markets to a 60-second Chainlink TWAP in Aug 2026 after a snapshot attack (sourced for the change; the attack and its cost are secondary).
- **Operators already sell short Rounds, but mostly on prices, sports micro-markets and random games.** Polymarket runs 5- and 15-minute crypto up/down markets (sourced); Pumpcade runs 1-30 minute markets on Solana (sourced, from note 11); sportsbooks sell micro-markets from Sportradar and others (secondary). I found no operator selling 30-second onchain-event Rounds (inferred from absence; search was shallow).
- **Implication for the payer question (ticket 30):** a vendor selling an operator a Round game gets the most defensible value from games the operator can verify cheaply (onchain events, public randomness, TWAP prices), not from sports data it would have to relicense (inferred).

## 1. Cross-cutting facts

### What "settled within seconds" needs
- A data source that publishes the outcome within a few seconds of the Window end, a rule that pins which value counts (a timestamp or block number, not "when the job runs"), and a stored raw record (note 11, sourced).
- A hard Cutoff before the read point wider than the feed's delay (note 11, sourced from Pyth best practices). At 30 seconds this squeezes the betting time hard: with a 10-second Cutoff margin, bettors have about 20 seconds (inferred).
- Delay or dispute rule: note 11's default is tie -> refund; feed unavailable at read time -> bounded retry, then void and refund (note 11, design recommendation). Polymarket's current changelog does not state tie or refund rules (sourced: docs.polymarket.com/changelog/predictions); one forum post claims ties count as "Up" and a grace-period void exists (secondary, low quality).

### Polymarket's 5-minute crypto markets (the closest live comparator)
- Launched 12 Feb 2026 with taker fees up to 1.56% at 50% probability. From 7 Aug 2026 they resolve on a Chainlink-computed TWAP rather than a single snapshot; from 14 Aug 2026 the lookback is 60 seconds (was 30). The opening price and the settlement price both come from the same TWAP feed. (sourced: https://docs.polymarket.com/changelog/predictions)
- Back-to-back markets share one 60-second TWAP at their boundary, which settles one and sets the next strike (secondary: search summary of third-party write-ups, not the changelog).
- The reason for the switch was a documented attack on snapshot prices, reported as costing retail traders $8.2m (secondary: Genfinity; I did not open it).
- Lesson: for back-to-back Rounds, use a time-averaged or windowed value, not a single instant (inferred from the above).

## 2. Domains

For each: source, latency, cost, licence, settle-in-seconds, dispute, manipulation, who offers it.

### 2.1 Onchain events (blocks, gas, logs, DEX swaps)

- **Source:** the chain itself, read over a public RPC. Base builds blocks every 2s; with Flashblocks, 200ms preconfirmations (sourced: https://docs.base.org/base-chain/network-information/block-building). The Denim upgrade replaces Flashblocks with canonical 200ms blocks; live on Base Sepolia since 21 Oct 2026, Base Mainnet "targeting November 2026", a planning target not a date (sourced: https://docs.base.org/upgrades/denim/migrate-from-flashblocks). After Denim, subscribe with `newHeads` and `logs` instead of the Flashblocks methods (same page).
- **Cost and licence:** $0 for public RPC (`https://mainnet.base.org`, sourced: https://docs.base.org/get-started/connect-to-base). That page states no rate limits or production-use terms; I did not find them (unverified). A paid RPC is an upgrade path (inferred). Chain data has no licence issue (inferred).
- **Settle in seconds:** yes; a Round can be settled by a contract reading `block.number`, `block.basefee` or a log in a block at a pinned height, in the same block or the next. Two caveats (inferred): chain reorgs on a rollup sequencer, and block-time variation, so define the Window in block numbers, not wall-clock seconds.
- **Dispute/delay:** no human data source; the failure mode is chain halt or sequencer outage (inferred). Rule: if no block at the pinned height by a deadline, void and refund.
- **Manipulation:** the weakest point.
  - Gas and base fee: a bettor can spam transactions to raise gas in a block; cost grows with the target (inferred).
  - Block hash or parity as an outcome: the sequencer controls ordering; a bettor who is not the sequencer cannot pick the hash cheaply, but the sequencer operator could (inferred; Base uses a single sequencer, a general fact I did not re-verify).
  - DEX volume: wash trading moves it at the cost of fees, cheap on small pools; use a large pool or a count that is expensive to fake (inferred).
  - The operator can pick the metric, so it can be made hard to move: for example, the number of unique senders in a block, not volume (inferred).
- **Who offers it:** I found no operator offering onchain-event Rounds. Chain-reading is generic and trustless, so there is no data vendor to compete with (inferred). The closest prior art in this repo is none; unverified.

### 2.2 Public randomness (not an event, but already sold)

- **Source:** drand (publicly verifiable, unbiased, unpredictable randomness, per its overview: https://docs.drand.love/docs/overview, sourced). I did not get round period, relay availability or cost from that page (unverified). I recall the quicknet chain emits a value every 3 seconds (from memory; not verified here, treat as inferred). Chainlink VRF is the paid alternative (not researched).
- **Settle in seconds:** yes if the round period is shorter than 30 seconds and the value can be verified onchain or by a signature (inferred).
- **Manipulation:** the point of the design is that no party can bias it, provided you commit to the target round before it is published (inferred).
- **Who offers it:** crypto casinos already sell instant, random-based games; the product is content rather than a prediction. I did not research which operators or suppliers (unverified).
- **Fit note:** it is not "an event" in the ticket's sense, but it settles any fixed-odds Round automatically at $0. It also changes the legal character (a game of chance rather than a prediction market), which ticket 29 must judge (inferred).

### 2.3 Social signals (Farcaster casts and likes)

- **Source:** Neynar webhooks and the Farcaster hub/Snapchain. Neynar's webhook doc documents `cast.created` for selected channels only; it does not document reaction events (sourced: https://docs.neynar.com/docs/how-to-use-neynar-webhooks). Reactions can be read through the Snapchain Reactions API (listed, not opened: https://docs.neynar.com/snapchain/httpapi/reactions.md).
- **Latency:** no figure given. The doc says "Webhook events might be delayed at times of heavy load" (sourced). A counted event arriving late breaks a 30-second Window (inferred).
- **Cost:** Neynar Free plan lists 10M credits a month, 600 RPM, 10 webhooks, and Webhooks and Hub endpoint included; Scale is $249 a month (sourced: https://docs.neynar.com/reference/what-are-the-rate-limits-on-neynar-apis.md). Cast search is limited to 120 RPM on Free.
- **Licence:** Neynar's terms for commercial or betting use not read (unverified). Farcaster is an open protocol, so running a hub is a way around vendor terms but costs hosting (inferred).
- **Settle in seconds:** a count of casts in a channel in a 30-second Window can be computed if delivery is on time; I have no evidence it is (inferred).
- **Manipulation:** high. Anyone can post or like from many accounts; a bettor can create the outcome. Defences: count only accounts above an age/score threshold, which brings in a trust list (inferred).
- **Who offers it:** per note 19 (`.scratch/creator-feed-markets/research/19-...`) creator markets in the feed exist; the map puts Farcaster distribution out of scope. As a data source only: not found offered as Rounds (unverified).

### 2.4 Livestream events (Twitch, YouTube Live)

- **Source (Twitch):** EventSub gives `channel.chat.message`, `channel.cheer`, `channel.subscribe`, `channel.raid`, `channel.hype_train.*`, `stream.online`, `channel.follow` (sourced: https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/). Delivery is "at least once", so duplicates occur and you must dedupe on `message_id` (sourced: https://dev.twitch.tv/docs/eventsub/). The pages I read give no latency figure or subscription cost.
- **Source (YouTube):** default quota 10,000 units a day; `liveChatMessages.list` costs 5 units a call (sourced: https://developers.google.com/youtube/v3/determine_quota_cost). Polling every second would use 18,000 units an hour, so a day-long stream exceeds the default quota unless raised (arithmetic from the figures, inferred).
- **Licence:** I could not read the Twitch Developer Services Agreement or Terms of Service body (fetch returned navigation only), so whether betting on Twitch events is allowed is **unverified**. A secondary report says Valve's 2016 skin-gambling crackdown flowed into Twitch's terms (secondary: PCGamesN snippet); that is about skins, not event betting.
- **Settle in seconds:** Chat/cheer/raid counts could settle if EventSub delivers quickly (no figure found). "Game outcome inside a stream" needs a second source and is not automatic (inferred).
- **Manipulation:** highest of all. The streamer or chat can produce the outcome (cheers cost money but a streamer can self-cheer; chat can spam). Not safe for a Round where real stakes sit on the count (inferred).
- **Who offers it:** I found no operator offering Twitch-event Rounds (unverified).

### 2.5 Esports (kills, rounds)

- **PandaScore:** plans per game per month: Free (schedules, results; no live), Historical from 400 EUR, Live Basic from 1,000 EUR (live WebSocket, limited live statistics), Live Pro contact sales. "These stats plans are only available to customers with non betting-related usage"; betting use is directed to sales. A separate low-latency product is sold to prediction users through sales. Stream-synced data exists for LoL and CS only. (sourced: https://www.pandascore.co/pricing)
- **Riot Games (LoL, Valorant):** "Your product cannot feature betting or gambling functionality" (sourced: https://developer.riotgames.com/policies/general). Production access needs product registration and audit (same page).
- **Valve (CS2, Dota 2):** Valve said in 2016 that running a gambling business through its OpenID/Web API is not allowed and sent cease notices; the written API terms did not mention gambling then (secondary: ESPN and Dot Esports reports via search). I did not read the current Steam API terms or Game State Integration docs (unverified).
- **Official-data vendors:** Genius Sports owns Abios (bought 2021) and partnered with GRID in 2024 for official esports data; other vendors include Bayes and Sportradar's esports module (secondary: search summary of track360.io and grid.gg). Prices not public.
- **Latency:** PandaScore Live is stream-synced; no latency figure was on the pricing page (unverified).
- **Settle in seconds:** "kills in the next 30 seconds" needs a live play-by-play feed, which is the paid Live Pro tier (inferred from the plan table).
- **Manipulation:** players or insiders can influence a single round; match-fixing risk is known in esports (inferred, no source). Operators pay vendors partly for integrity monitoring (inferred).
- **Who offers it:** Stake and BC.Game list esports markets (secondary: OddsPapi listing); I found no source naming their data supplier.

### 2.6 Sports (points, possessions)

- **Free tiers** (from note 11, sourced there): too slow and too few calls for 30-second Windows.
- **Sportradar:** trial is non-commercial, 30 days, 1,000 requests, 1 query per second; the US Master T&Cs have a "No Gambling" clause barring betting use without express written approval (secondary: search result citing developer.sportradar.com; I could not open the clause, the fetched page was an index). Pricing is not public; a third-party comparison puts odds products at about $500-5,000+ a month (secondary, unverified).
- **Latency:** Genius says its official feeds reach licensed books in under one second; Sportradar's lowest live-latency class expects delays under four seconds (secondary: search summaries; vendor claims, not measured by me).
- **Official-data rules:** several US states require official league data for in-play markets, and Genius is said to hold the in-play NFL lane through 2029 (secondary). A crypto operator outside those states is not bound by that (inferred), but the vendor licences still apply.
- **Settle in seconds:** a "next possession" or "next point" Round is exactly the micro-market sportsbooks run, but resolution is by the vendor's scouts, who are humans entering data from the venue (secondary: Genius/Sportradar scouting disputes reported; the claim of human scouts is inferred from the "in-stadia scouting" wording). So "no human reporter" is false at the source (inferred).
- **Manipulation:** known integrity risk; leagues and regulators are narrowing micro-bets (MLB capped pitch bets, secondary).
- **Who offers it:** Sportradar's Betradar is the largest micro-market supplier (secondary).

### 2.7 Others found

- **Crypto prices (covered in note 11):** the mature case; Polymarket and Pumpcade both run 5-30 minute markets here (sourced). 30 seconds is below any operator window I found (Pumpcade's shortest is 1 minute; Polymarket's is 5 minutes) (sourced).
- **Weather, flight times, traffic:** feeds update minutes to hours apart, so 30-second Windows do not fit (inferred; no source checked).
- **Prediction-market odds as an event (Pumpcade beta uses Polymarket/Kalshi YES odds):** sourced in note 11. Dependent on a third party's API and terms (not read).

## 3. Comparison table

| Domain | $0 solo | Settles in seconds | Betting use allowed | Manipulation risk | Already offered |
|---|---|---|---|---|---|
| Onchain events (Base) | Yes | Yes (200ms blocks on mainnet pending Nov 2026) | No licence issue (inferred) | Medium; metric-dependent | Not found |
| Public randomness (drand) | Yes | Yes if round period < Window (unverified) | Not applicable | Low | Random games are common (unverified) |
| Farcaster social | Free tier | Unproven (delays noted) | Unverified | High | Not found |
| Twitch/YouTube live | Free API | Unproven | Unverified | Very high | Not found |
| Esports | No (EUR 1,000+/game/month) | Only on paid live | PandaScore stats plans: no; Riot: no | Medium | Yes, via licensed vendors |
| Sports | No (enterprise) | Seconds, with human scouts at source | Needs written approval | Medium | Yes, micro-markets |
| Crypto prices (note 11) | Mostly | Yes with TWAP | Varies | Medium; TWAP reduces | Yes (Polymarket, Pumpcade) |

## 4. What stayed unverified

- Twitch Developer Services Agreement and Terms of Service gambling clauses (fetched pages had no body text).
- The Sportradar No Gambling clause text; only seen via search snippet.
- Current Steam Web API and Game State Integration terms; Valve's position known only from 2016 reports.
- drand round period, relay terms and cost; Chainlink VRF cost.
- Base public RPC rate limits and production-use terms; whether Base mainnet Denim ships in Nov 2026.
- Neynar webhook latency, reaction webhook availability, and its commercial terms.
- Twitch EventSub latency; Twitch and Neynar terms on betting use.
- Which supplier Stake or BC.Game uses for esports; any operator selling onchain-event or 30-second Rounds (absence inferred from a shallow search).
- Sports and esports vendor prices beyond PandaScore; Genius and Bayes pricing not public.
- The $8.2m snapshot-attack figure for Polymarket (secondary only).
- Sequencer centralisation and reorg risk on Base for a 200ms block chain (general knowledge, not checked).
- All secondary search summaries should be rechecked against the cited primary pages before relying on them in a pitch.
