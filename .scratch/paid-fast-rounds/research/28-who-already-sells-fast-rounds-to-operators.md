# Who already sells fast rounds to operators

Research for ticket 28. Not legal or investment advice. Date: 2026-10-26.

Labels: **sourced** = stated by a first-party or official page I fetched; **sourced (secondary)** = news, review or aggregator report of a primary source I could not open; **inferred** = my reasoning. Many search hits are affiliate or press-release sites; where a number rests only on those it is marked secondary.

## Summary

- **Nobody I found sells an automatic 30-second Round to operators as a B2B product.** The shortest B2B-sold formats are crash games (rounds of roughly 8-30 seconds, sold by licence to thousands of casinos) and Betgames-style live-dealer draws (4 minutes). Sub-minute prediction exists only as consumer products (Pumpcade's 60-second floor, Twitch's 30-second API floor), not as something an operator buys (inferred).
- **Crash is the closed lane.** Spribe's Aviator is sold B2B to thousands of operators and is claimed to hold over 90% of crash (sourced for operator reach on a Spribe ad feature; the 90% and revenue are Spribe's own claim via secondary). Revenue share is unpublished; one analyst guess is 10-15% of GGR (secondary, estimate). A solo dev cannot out-distribute this, and a Round game that is a house-banked bet puts the dev in the gambling-licence chain (inferred).
- **Up/down on crypto is the closed lane for consumers, and it is giving operators a free substitute.** Polymarket runs 5- and 15-minute up/down on Chainlink TWAP, with taker fees peaking 1.56% (sourced). Limitless runs 5- and 15-minute on Base (sourced, secondary). Kalshi runs 15-minute across 30 series and reportedly 86% of its September crypto volume (secondary). Polymarket exposes a builder-code programme that pays integrators fees (secondary; official page only partly seen). The fastest window these sell is 5 minutes, not 30 seconds.
- **Micro-betting for operators exists but is sports-only and big-ticket.** Simplebet (B2B micromarket pricing) was bought by DraftKings; its 10-K reports about $134.6m total consideration (sourced, via search summary of the 10-K). Its customers are sportsbooks; it prices events, not fixed-clock rounds (sourced). No published price list (not found).
- **Gaps that look open for a solo dev (inferred):** (1) a sub-minute Round that settles with no person on events other than coin price, delivered as an embeddable or API product; (2) a non-bettor payer, a streamer or sponsor-funded prize pool, since Twitch and Kick run points-only and no one sells paid, funded versions; (3) Pumpcade's own status is unclear, which may leave its niche open or signal weak demand. **Looks closed:** crash-style house-banked games, crypto up/down at 5-15 minutes, and sports micromarket pricing.

## 1. Simplebet (and DraftKings)

- **What it is:** A B2B provider of in-play micromarket content and pricing for NFL, MLB, NBA, NCAAF, NCAAB and NHL, using in-house pricing models. DraftKings said it would improve "quality, breadth and speed of data" (sourced, secondary: SportsBettingDime reporting the Aug 28-29, 2024 announcement; no price in the announcement).
- **Who pays:** Sportsbooks. DraftKings took a 15% stake and a multi-year deal in 2021, and was about 60% of Simplebet's turnover (secondary: casino.guru/NEXT.io-type reports).
- **Format / window:** A micromarket is a single next-play bet (e.g. result of the next pitch). Window length is the time between plays, not a fixed clock (inferred); no published figure found.
- **Settlement source:** Official sports data feeds (inferred; not stated in what I read).
- **Price paid for the company:** DraftKings' FY2024 10-K, as summarised by search, shows signing Aug 28, 2024, close Dec 3, 2024; about $36.0m cash, $45.1m equity, $53.5m contingent consideration, total $134.6m (sourced; I did not open the note myself, the search tool read it). JMP's $195m estimate is different (secondary).
- **Operator pricing:** Not published.
- **Traction:** Concentrated in one customer; the sale suggests the independent micro-betting vendor model was hard to sustain (inferred).

## 2. Betgames and live-dealer number games

- **Betgames:** B2B licensed (Malta Gaming Authority B2B Type 1, UKGC, others) from a Lithuanian company; lists Betsson, Betway, Entain, Parimatch and others as partners; has an operator contact form (sourced: betgames.tv/game/lucky-6/).
- **Lucky 6:** Draw "every 4 minutes" (sourced: same page). Third-party reviews put the betting window at about 3 minutes and RTP at about 95% (secondary, review sites). One old page says 5 minutes; that is another provider (tvbet) (secondary).
- **Who pays:** Operators (retail and online), by licence. Pricing not published (not found); typical studio-content revenue share is a GGR percentage (inferred).
- **Settlement:** A live studio draw streamed on video, i.e. a person or machine in a studio (sourced, secondary).
- **Gap versus Rounds:** 4 minutes with a human-run studio. A 30-second automatic Round is about eight times faster and needs no studio (inferred).

## 3. Crash and "up/down" games from casino providers

- **Spribe Aviator:** Sold B2B directly and through aggregators (Pragmatic Solutions, Hub88, SoftGamings, BetConstruct and others) to 5,500+ operators, per SBC/Spribe claims (secondary). A Spribe advertising feature says "more than 2,000 brands" (sourced, but an ad and unverified). RTP 97%, configurable lower by operators (secondary).
- **Revenue share:** Spribe does not publish it. The 10-15% of GGR is an analyst's guess (secondary).
- **Scale claims:** 77M monthly players, over 90% of crash, €160B wagered in 2025 (Spribe's claims, via secondary). Latka revenue estimate $200m for 2026 (secondary, estimate).
- **Round length:** Not stated by Spribe in the pages I read. Pragmatic's Spaceman is reported at about 8-12 seconds average with 5-10 second betting gaps (secondary, affiliate sites; low quality).
- **Settlement:** A certified random number generator, not an outside event (secondary).
- **In-house crash:** Stake Originals and BC.Game run their own, claimed at 99% RTP and provably fair hash chains (secondary, affiliate/review sites). Crypto casinos therefore already build this themselves (inferred).
- **Gap versus Rounds:** Crash is RNG, not an event prediction, and is house-banked. Operators buy it as casino content. A Round that settles on a real event would need a different sell: "prediction content," not casino content (inferred).
- **Dispute:** Aviator LLC is suing Flutter over rights to Aviator (secondary): IP in this lane is contested.

## 4. Pumpcade

- **What it is:** Solana platform for short prediction markets inside livestream chats, starting with Pump.fun. Markets run 60 seconds to 30 minutes, parimutuel, settled by "official API calls or deterministic data" (sourced: The Block, Apr 2, 2026, page updated Oct 19, 2026; the settlement claim is the company's).
- **Who pays:** Not stated. The article describes no revenue mechanism and no fees (sourced: The Block). Later reports say the model is parimutuel (secondary), so the revenue is presumably a cut of pools (inferred).
- **Funding:** $1m pre-seed led by Pump.fun (Apr 2026), then a $5m seed with Jump Crypto and Foundation Capital (Apr 14, 2026), implying about $44m valuation (secondary: Bitget/Cryptopolitan-type reports).
- **Traction:** Private beta since January 2026, about 500 users, thousands of markets on testnet; mainnet and open beta planned for Q2 2026 (sourced: The Block). Current status not confirmed.
- **Warning sign:** `pumpcade.com` returned a Porkbun page saying the domain has expired and is for sale at auction (sourced: fetched page). It could be a parked or changed domain; I could not tell whether the product moved, rebranded or died. Treat as unverified.
- **Relevance:** The closest direct competitor to a 30-second Round, but it sells to bettors and streamers inside Pump.fun, not to operators (inferred). Sub-minute is the floor of its range.

## 5. Limitless, Polymarket and Kalshi short markets

- **Polymarket:** 15-minute crypto markets launched Oct 2025 (secondary); taker fees enabled on them Jan 5, 2026 and on 5-minute markets from launch Feb 12, 2026, peaking at 1.56% at 50% probability, with maker rebates paid daily in USDC (sourced: docs.polymarket.com/changelog/predictions). From Aug 7, 2026 up/down markets settle on Chainlink TWAPs: 60-second lookback for 15-minute and 4-hour, 5-minute markets moved from 30 to 60 seconds on Aug 14 (sourced: same). The US app added a Bitcoin Up or Down format on Sept 22, 2026 (secondary).
- **Polymarket builders:** Third-party apps can route orders with a builder code and charge their own fee (reported 0-100 bps taker, 0-50 bps maker), plus weekly USDC rewards, and the programme launched with $2.5m in grants (secondary: guides; the official page appeared only as a snippet). This is a way for an operator, or the dev, to earn from short-market flow without making the markets (inferred).
- **Limitless (Base):** Hourly, daily, 15-minute and 5-minute crypto Up/Down; CLOB; USDC (secondary: limitless.exchange pages in search). Fee schedule: AMM markets 0.40%; new venues taker fee 5% x (1 - price); makers pay nothing; user-created custom markets charge a 2% pool fee to the creator (sourced: docs.limitless.exchange fees page). The docs show no builder or partner revenue share. Its docs offer a programmatic API for platforms (sourced, thin).
- **Kalshi:** 15-minute up/down on 30 series (secondary: Cointelegraph/Gaming America); settles on the average price over the minute before close versus the minute before open (sourced: help.kalshi.com), most crypto markets on a CF Benchmarks index (sourced). Listed on Coinbase since Oct 6, 2026 (secondary).
- **Who pays:** Retail bettors and market makers, via trading fees. Not operators.
- **Gap versus Rounds:** Minimum window is 5 minutes, and the settlement lookback alone is 60 seconds, which makes sub-minute Rounds on the same method impossible without a different price rule (inferred).

## 6. Twitch and Kick prediction tools

- **Twitch Predictions:** Channel Points, not money. Secondary sources give a window of 1-30 minutes in the app and 30-1800 seconds via the API; one stake limit of 10 to 250,000 points; 2-10 outcomes; one prediction at a time (secondary: Metricool/Streamrise-type guides; I could not reach the API reference section; ticket-relevant, verify).
- **Kick Predictions:** Added around May 2025 as part of Channel Points; two outcomes; voting length chosen by the streamer; winners share points in proportion; refunds if unresolved in 24 hours (sourced: help.kick.com streamer guide; the minimum voting length is not stated).
- **Who pays:** Nobody; free to the streamer and viewers, platform-run (inferred).
- **Settlement source:** The streamer or a moderator picks the outcome by hand (sourced: Kick guide). Not automatic.
- **Gap:** These show viewers like fast prediction, but they have no money, no oracle and no sponsor-funded prize product (inferred).

## 7. Other things found

- **White-label prediction platforms:** NinjaTrader Connect, Leverate, Devexperts, Matchbook B2B, Turbo Stars, SOFTSWISS and others sell turnkey event-contract platforms to brokers or operators; a pricing guide quotes $5,000-$50,000+ a month or revenue share, and Matchbook says a full white label takes 8-12 weeks (secondary: aggregator and vendor pages; low quality). These are 15-minute-or-longer and mostly regulated-futures focused; none advertises sub-minute.
- **Hyperliquid HIP-4:** Outcome markets, with permissionless deployment arriving on mainnet in late August 2026; templates are mostly daily so far (secondary). A possible future place for short markets, not now.
- **Azuro:** Listed in B2B roundups as a crypto-native on-chain pool option; no short-duration detail found (secondary).

## Pricing summary

| Seller | Who pays | Published price? |
|---|---|---|
| Simplebet / DraftKings | Sportsbooks | No |
| Betgames | Operators | No |
| Spribe Aviator | Operators | No (analyst guess 10-15% GGR) |
| Pumpcade | Unclear | No |
| Polymarket | Traders | Yes: taker fees up to 1.56%; builder fees 0-100 bps (secondary) |
| Limitless | Traders | Yes: AMM 0.40%; taker 5% x (1 - price) |
| Kalshi | Traders | Linked fee schedule, not read |
| Twitch / Kick | Nobody | Free |
| White-label platforms | Brokers | $5k-50k+/month (secondary) |

## Gaps a solo dev could fill (all inferred)

1. **Sub-minute, no-person settlement.** Nobody sells below 5 minutes with automatic settlement. Obstacle: the best price feeds average over 60 seconds to resist manipulation, so a 30-second Round needs a different resolution rule or event type.
2. **Events beyond coin price.** Operators already have crypto up/down from Polymarket and Limitless for free; a Round on live events (esports, stream outcomes, game state) is the differentiator.
3. **Sponsor- or operator-funded prize Rounds** (no stake revenue), matching the map's legal rule. Twitch/Kick give the format but no money.
4. **Drop-in delivery:** an embed or API that a crypto casino adds to its lobby, like Betgames' integration, rather than a new venue.

**Looks closed:** crash and RNG games (Spribe dominance, in-house copies, IP fights); crypto up/down at 5-15 minutes; sports micromarket pricing; generic white-label platforms.

## Unverified

- Spribe's pricing, the 5,500 operator count versus "2,000 brands", and the 90% share: all Spribe claims or estimates; no filing found.
- Betgames pricing, integration terms, and whether any of its games run under a minute.
- Pumpcade's current status (domain for sale), revenue model, mainnet launch, and who pays.
- Twitch API `prediction_window` limits and Kick's minimum voting period (official reference not reached).
- Polymarket's builder programme official terms (only secondary guides read); Kalshi's fee schedule; Limitless 5-minute market terms.
- The Simplebet 10-K figures were read through a search summary, not by me; Simplebet customers beyond DraftKings.
- Other sellers not searched: Sportradar and Genius micro-markets, Evolution, Pragmatic crash internals, Hacksaw, Gamdom, Azuro detail, Chainlink-based B2B offerings, Kick/Twitch third-party bet overlays.
