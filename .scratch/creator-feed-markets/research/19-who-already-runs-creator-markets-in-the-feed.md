# 19. Who already runs creator markets in the feed

Researched 2026-10-25. Method: web search plus page fetches. Sources are labelled
[P] primary (the product's own docs, site, repo or announcement), [S] second-hand
(press, blogs, aggregators), or [I] inferred by me. Many first-party pages
(Farcaster app pages, bracky.app, Limitless X posts) could not be fetched, so some
cells say "not found" rather than "none".

## Summary and verdict

**Verdict: KEEP the pick.** I found no product that lets anyone create a market, seed
it, earn its fees, have it settled only by a price feed or onchain state, and trade it
inside the Farcaster or Base App feed with 1,000 or more weekly users.

- The closest competitor is **Limitless User-Generated Markets (UGM)**. It launched
  2026-06-02 on Base. Any signed-in user can create a price-target market and earn a
  share of taker fees. Price markets resolve via Pyth or Chainlink [P]. It has a
  reported 162 creators, 1,611 markets and $2.2M volume in its first beta month [S].
  It lives on limitless.exchange, not in the feed. I found no official Limitless mini
  app.
- The only feed wrapper found, **Swipen**, is a third-party Base Mini App showing
  Limitless markets. It has 0 stars, 0 forks, no usage data and no creator flow [P].
- Base App stopped supporting the Farcaster mini-app spec on 2026-04-09 [S], so
  "inside the feed" now effectively means Farcaster clients (Warpcast and others).
- Feed-native prediction apps with traction (**Ponder**, 25k+ "active ponderers" [P];
  the unnamed FORKOFF app, 5,840 WAU [P]) are crowd-vote or accuracy-token games, not
  creator-seeded, chain-settled markets as far as their pages say.
- Nobody found runs market-cap or price-target markets on Zora or Clanker coins on
  Base. Zora itself has shrunk (section 3).
- Kill-rule risk to watch: Limitless could ship a feed-native surface, or someone
  could skin UGM in a mini app. At that point the "narrow to Zora and Clanker coins"
  branch applies. Nothing in the evidence shows that today.

## 1. Products in the feed (Farcaster / Base App)

| Product | Surface | Chain | Who creates | Creator fee | Settlement | Weekly users | Launch | Source |
|---|---|---|---|---|---|---|---|---|
| Swipen (0xumutkk/Swipen) | Base Mini App, TikTok-style feed (tagged farcaster-mini-app) | Base | Not stated. Pulls markets from Limitless `GET /markets/active`; no creation flow described | None described (only an optional builder-code env var) | Limitless's (users "redeem after settlement") | None published. Repo: 0 stars, 0 forks | Not shown. Repo last updated ~Aug 2026 [S] | [P] https://github.com/0xumutkk/Swipen |
| Ponder | Farcaster mini app (Warpcast Mini-App Explorer), web at weponder.io; listed in a Base Mini App starter pack [S] | Rewards in USDC on Base | Users can create polls and "earn a percentage of the rewards" | Percentage not published; entry stake $0.50-$10 | Not a price feed or onchain state. About 24 hours of hidden votes, then the pool pays players who picked the most popular option (Keynesian beauty contest) | "25,000+ active ponderers", "$250,000+ total volume". Not weekly | Not stated | [P] https://ponder.social/ ; [S] https://paragraph.com/@cryptso/mini-app-starter-pack |
| Unnamed prediction mini app, FORKOFF Q1 2026 audit (Case 1) | Mini app on all three wallet surfaces with a three-state frame | Base | Not stated (anonymized) | Not stated; a prediction token pays "on accuracy" | Not stated | 5,840 WAU at week 4, 6,720 at week 12 | Not stated (post dated 2026-04-30) | [P] https://forkoff.xyz/blog/ecosystem/farcaster-mini-apps-distribution-2026 |
| Bracky | Farcaster account/agent, bracky.app (403 to my fetcher) | Base | Appears to be Bracky itself; top holders of its posts get "pre-mine" access to its markets | Not found | Not found | Not found | Not found | [S] search snippet of https://farcaster.xyz/bracky |
| Limitless's own mini app | None found. Limitless was listed under "Make Predictions" in a Base Mini App starter pack (~Dec 2025) [S]. Farcaster appears only as a footer link | Base | See section 2 (UGM, web app) | See section 2 | See section 2 | None published (see section 2) | n/a | [S] https://paragraph.com/@cryptso/mini-app-starter-pack |
| CeloCaster | Farcaster mini app (finance category, by chriswilder) | Celo (not Base) | "Anyone" can create or join bets (directory blurb) | Not found | Price bets via Chainlink feeds; others "community-voted" | Not found | Not found | [S] search snippet of https://farcaster.xyz/miniapps/wmU6dgTaCyPA/celocaster (page not fetchable) |

Other names seen but not researched in depth: Bookie, Onit, PredictBase, Truemarkets,
Upshot (same starter pack [S]), Delulu (Celo, spotlighted by Celo's Farcaster account
[S]), TMRW (video hot-takes market [S]).

Platform caveat: Base announced on 2026-03-12 that Base App support for the Farcaster
mini-app spec and Neynar-powered metadata and notifications would end 2026-04-09. The
Base App then treats apps as standard web apps. Farcaster clients keep their
integrations. [S: https://paragraph.com/@arcabot/base-and-farcaster-split-the-mini-app-stack,
which quotes Base's migration guide; I did not open Base's own post.]

## 2. Permissionless creator markets elsewhere

| Product | Surface | Chain | Who creates | Creator fee | Settlement | Traction published | Source |
|---|---|---|---|---|---|---|---|
| Limitless UGM | limitless.exchange web (Community badge) | Base | Any signed-in user, with a daily limit and per-duration caps. Users "propose and fund" markets; minimum seed not stated | Share of taker fees, rate set at creation and frozen for the market's life, paid daily in USDC; taken before the maker-rebate pool. Exact rate not published | Price markets: Pyth (majority) or Chainlink TWAP (5/15-minute crypto up/down), automatic. Caveat: for community markets the docs say "the creator's wallet reports the outcome", synced every 15 minutes, so UGM is not purely feed-settled in general [P]. That UGM price-target markets use Pyth is [I] from the launch blog ("pick an asset, define a target price") | 162 creators, 1,611 markets, $2.2M volume in first beta month, "reportedly", unsourced [S]. No weekly users. Protocol-wide: an old DefiLlama snapshot showed 7-day volume of $597k [S]; a Dune-based report gave ~39k monthly active traders in 2025 [S]. From 2026-09-07 UGM trading is excluded from points [P] | [P] https://limitless.exchange/blog/limitless-launches-user-generated-markets-anyone-can-now-create-and-earn-from-their-own-prediction-market ; [P] https://docs.limitless.exchange/user-guide/user-generated-markets ; [P] https://docs.limitless.exchange/user-guide/market-resolution ; [P] https://docs.limitless.exchange/changelog ; [S] https://theblackswans.substack.com/p/limitless-the-prediction-market-that |
| Opinion (BNB) | Web app | BNB Chain | Mainnet 2025-10-16 [S]; permissionless creation opened in stages (whitelist first; one review says permissionless from Nov 4) [S]. Opinion AI checks rules and resolvability | No creator-fee terms found; taker fees 0-2% [S] | Not confirmed in sources fetched | None found | [S] https://www.globenewswire.com/news-release/2025/10/16/3167923/0/en/Opinion-the-YZi-Labs-Backed-Prediction-Market-Announces-Mainnet-Launch-Exclusively-on-BNB-Chain.html |
| "Opinion Market" (XYZVerse; a different project, do not conflate) | Web | BSC | Anyone; $20 USDC creation fee | 25% of the 4% pool fee | Parimutuel: the side with more money wins | None; launched 2026-04-08 | [S] https://www.bitget.com/news/detail/12560605352338 |
| Melee Markets | Web | Solana | Anyone, any topic | "Up to 20%" per aggregator [S]; the official page says only "a cut of every trade, forever" [P] | Not covered on the page I read | Official page numbers are illustrative samples. A claim of $317k creator revenue on $15.87M volume for one market is [S]. $3.5M seed, 2025-09-24 [S] | [P] https://pmm.melee.markets/ ; [S] https://solanacompass.com/projects/melee-markets |
| Path Protocol | Infra for third-party venues | Solana | Developers deploy venues via a permissionless registry [S] | 30% of protocol fees to stakers, 70% to treasury [S]; no per-market creator fee found | Oracle aggregation plus staked $PATH commit-reveal voting [S] | None found | [S] Solana Compass / The Grid snippets; no primary source reached |
| Zeitgeist | Web | Polkadot | Anyone | Market-creator fees announced ~Dec 2023 [S]; current status unconfirmed | Not verified here | None found | [S] https://www.linkedin.com/company/zeitgeistpm (snippet) |
| Xmarket | Web | BNB Chain | Anyone (invite-code beta, Feb 2026) | Up to 50% of fees (company claim) | Not stated | None; sponsored press release | [S] https://cryptobriefing.com/prediction-markets-have-a-creator-problem-2/ |
| Pumpcade | Pump.fun livestream chats | Solana | Users create markets in livestream chat; manipulable types such as "mentions" excluded | Not found | Resolves in seconds to minutes; mechanism not found | $1M pre-seed led by Pump.fun (2026-04-02) [S]; a $5M round is less corroborated | [S] https://www.theblock.co/news/deals/2026-04-02-pump-fun-pre-seed-funding-round-livestream-prediction-markets-pumpcade-396213 |

## 3. Markets on Zora or Clanker coins on Base

I found no product running market-cap or price-target markets on Zora creator coins or
Clanker tokens. Searches covered Polymarket, Limitless, Myriad and Context, and
returned only price pages and generic forecasts. This is absence of evidence: I did
not browse every market list, and Limitless's price markets could cover any asset it
lists. Context:

- Zora's creator-coin push has weakened. Its CEO changed on 2026-09-09, it moved to
  multi-chain trading pairs, and ZORA is at about a $17M market cap (-95% from its
  high) as of 2026-10-24 [S: CoinPaprika and aggregator summary; I did not open
  Zora's own announcements].
- Polymarket hired Zora's founder; a Yahoo Finance piece calls Zora's creator-coin
  experiment a failure [S].
- Clanker is now run by Neynar; the Clanker token's market cap is about $11-12M
  (aggregators, September 2026) [S].
- A search snippet suggested a Zora tie-up with the Context prediction marketplace;
  unverified.

## 4. Known failures

I found no documented case of a rugged or abandoned community market, and no
post-mortem. Evidence is thin; this is the honest result, not a finding of safety.
Relevant signals:

- Limitless community markets are creator-resolved, and creators may close, suspend or
  modify their markets under the Terms of Service [P]. That is the structural rug
  surface. Limitless says misresolved markets get refunded [P].
- Limitless removed UGM trading from its points program on 2026-09-07 [P]. No reason
  is given; [I] it is consistent with farming or wash-trading concerns, and the docs
  explicitly ban wash trading.
- Augur's permissionless creation drew "assassination market" controversy [S].
- Base's leadership reportedly conceded that onchain social and creator coins did not
  drive adoption, and the Base App moved toward finance [S, from a price-page summary;
  weak].

## Gaps

- No weekly-user figure for Limitless (or its UGM) was found anywhere.
- Limitless UGM docs omit the minimum seed, fee range and daily caps.
- Bracky, CeloCaster and Opinion terms are search-snippet level only.
- The 162-creator figure is unsourced; confirm in Limitless's Dune dashboard or X.
