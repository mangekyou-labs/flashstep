# A business that pays for 30-second rounds

Label: wayfinder:map

## Destination

A spec naming **one payer, one product and the outreach route to a paid commitment** (a pilot fee, deposit or signed LOI) for automatic, back-to-back 30-second Rounds settled without a person, on events beyond coin prices where they fit. The payer is never a bettor. The map's decisions are converted into that spec; the commitment itself is pursued by the separate task [Run the outreach](../run-the-outreach/task.md), which keeps the kill rule: stop if no payer commits within 4 weeks of the first send.

**Reached 2026-10-26:** [30-second Rounds for Base token teams: a white-label pilot](spec.md) (`ready-for-agent`, product only). Its build tickets are in [paid-fast-rounds-build](../paid-fast-rounds-build/issues/); manual QA and the outreach follow the build as HITL tickets 14 and 15.

## Notes

- Chosen on 2026-10-25 by the user after redrawing from [Creator markets in the feed](../creator-feed-markets/map.md): "can this be faster, like 30 seconds in resolving… just want to find a real business people will pay money for here." Its spec is shelved as prior art.
- Players stake real money; the user accepted the Vietnam legal risk on 2026-10-26 and will handle legal later. The developer takes no cut of stakes for now and is paid by the payer, never by bettors.
- Payer: crypto projects (token teams and Base launchpads) running white-label Round markets as Operator and Liquidity provider, per [The product and the payer](issues/30-the-product-and-the-payer.md). Licensed operators were the original default and are dropped.
- Onchain and provably fair settlement are tools, kept only where the payer values them: here, a payer-owned contract on Base that settles each Round from pool Readings.
- Budget: $0 cash, solo, part-time; about half the hours on outreach until a payer commits.
- This map plans only. Executing the outreach is the separate task [Run the outreach](../run-the-outreach/task.md), split out on 2026-10-26; its result feeds the spec but is not a ticket here. Building the product stays out.
- Skills every session should consult: grilling, domain-modeling, research, prototype.
- Research tickets run on Sonnet at medium effort. The user delegates them; don't fire them unasked.
- Plan, don't do. Don't build contracts or the product while this map is open; the demo is a rough sales asset.

## Decisions so far

- [Who already sells fast rounds to operators](issues/28-who-already-sells-fast-rounds-to-operators.md): nobody sells automatic 30-second Rounds to operators; crash games and 5-15 minute crypto up/down look closed, while sub-minute Rounds on non-price events, sponsor-funded prizes and an embed or API look open.
- [How crypto operators buy game content](issues/27-how-crypto-operators-buy-game-content.md): operators pay a GGR revenue share (10-15% is a secondary estimate) through aggregators that require a supplier licence and lab certificate (tens of thousands of EUR a year, out of reach at $0); Stake Engine is the one open door, exclusive to Stake with terms unverified; prediction platforms don't buy formats.
- [Legal exposure as a game supplier from Vietnam](issues/29-legal-exposure-as-a-game-supplier-from-vietnam.md): not taking bettor money doesn't clear a Vietnam-based dev (accomplice and "assisting gambling" provisions turn on knowledge); cases found are all operations, none a lone contractor; non-operator payers with no player stake carry lower risk; a US$20-200 lawyer consult is the cheap next step (7 questions ready).
- [Who you can reach and how much time](issues/25-who-you-can-reach-and-how-much-time.md): about 10 hours a week, half on outreach; no operator contacts and no named warm contacts; reach ranks crypto projects first, streamers and trading-group admins second, operators last (cold only); 20+ messages committed, clock starts on first send.
- [Which events settle in 30 seconds without a person](issues/26-which-events-settle-in-30-seconds-without-a-person.md): only onchain events on Base and public randomness fit a $0 solo dev; esports and sports data licences bar betting use; social and livestream outcomes are easy to manipulate in 30 seconds; ranking onchain, randomness, Farcaster, live streams, esports, sports.
- [The product and the payer](issues/30-the-product-and-the-payer.md): crypto projects (token teams and Base launchpads) pay a flat US$300 per 7-day pilot Campaign to run white-label, real-money Round markets as Operator and LP: the Speedrun AMM for memecoin up/down and a pari-mutuel pot for price and market cap thresholds, 1-30 s Windows settled from Base pool TWAPs, with a Stake cap; no cut of stakes; legal risk accepted.
- [The outreach plan](issues/32-the-outreach-plan.md): pitch 30 qualified crypto projects (Base pool ≥ US$100k liquidity, ≥ US$50k daily volume), at least 20 sends in 3 waves over Telegram and X, pitched on engagement and volume; the ask is the US$300 pilot with a US$100 deposit floor; first send by 2026-11-09 (no later than 2026-11-16).
- [The demo payers see](issues/31-the-demo-payers-see.md): a Kalshi-style player view of one live, payer-branded Round (rebrand by URL), mock feed, on branch `prototype/demo-payers-see`; a recording for cold DMs is left to [Run the outreach](../run-the-outreach/task.md).
- [The 30 qualified payers](issues/34-the-30-qualified-payers.md): 25 Base token teams clear the pool bar but none is Vietnamese and few have a Telegram; 0 launchpads confirmed at 5+ tokens (Virtuals has 4); 6 of 10 fallback Vietnamese trading groups verified. Target of 30 not met.
- [The 30 qualified payers](issues/34-the-30-qualified-payers.md): the list of 30 does not exist at the bar: 25 Base token teams qualify (none Vietnamese, 9 with a public Telegram), no launchpad reaches 5 tokens, and 6 Vietnamese trading groups are promoters, not payers.
- [Re-plan the outreach list](issues/35-re-plan-the-outreach-list.md): launchpads dropped as a class (Virtuals stays as one target); English-first to ~25 token teams, AXIS first; Vietnamese trading groups stay fallback only; pool numbers re-checked within 48h of each send; 3 waves, at least 20 sends.
- [What TAPL teaches the pitch](issues/36-what-tapl-teaches-the-pitch.md): TAPL is an offchain-resolved Sepolia hackathon PoC with LPs as the house and no customers or traction; decisions 30 and 32 stand, so avoid the "house" framing and don't cite it as demand.

## Not yet specified

- What the paid commitment turns into (depends on the outreach result): whether the Base Builder Grant still fits.

## Out of scope

- Consumer distribution in the Farcaster feed and creator-opened markets: the payer brings its own players, and Rounds run automatically.
- The dev running a real-money platform as Operator; the payer operates, per [The product and the payer](issues/30-the-product-and-the-payer.md).
- Licensed operators (casinos, sportsbooks) as payer: supplier-licence wall and cold reach only, per [The product and the payer](issues/30-the-product-and-the-payer.md).
- Building the product beyond the demo.
