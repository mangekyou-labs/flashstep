# 30-second Rounds for Base token teams: a white-label pilot

Label: ready-for-agent
Status: **build gated.** Building starts only after a payer makes a **Paid commitment** in [Run the outreach](../run-the-outreach/task.md). Until then, the demo is the only build. The kill rule stands: stop if no payer commits within 4 weeks of the first send.

> **"Rounds on your token every 30 seconds, on a page branded for you, settled automatically from your Base pool. You own the contract and set the stake limits. A 7-day pilot is US$300."**

Source: the map [A business that pays for 30-second rounds](map.md), mainly [The product and the payer](issues/30-the-product-and-the-payer.md), [The outreach plan](issues/32-the-outreach-plan.md) as amended by [Re-plan the outreach list](issues/35-re-plan-the-outreach-list.md), [The demo payers see](issues/31-the-demo-payers-see.md) and [What TAPL teaches the pitch](issues/36-what-tapl-teaches-the-pitch.md), plus [ADR 0004](../../docs/adr/0004-paid-fast-rounds-are-real-money-white-label-markets.md) and [ADR 0003](../../docs/adr/0003-creator-markets-use-a-pari-mutuel-pot.md). Terms follow the **Paid fast rounds** section of `GLOSSARY.md`.

Written 2026-10-26.

## Problem Statement

A Base token team wants its holders to keep trading and its pool to keep seeing volume between announcements. It has few ways to do that. Nobody sells it automatic, sub-minute prediction Rounds on its own token:

- Short crypto markets exist, but they are 5-15 minute up/down markets on major coins (Polymarket, Limitless, Kalshi), sold to bettors, not to token teams. Pumpcade (1-30 minutes, Solana) is the closest, and its mainnet status is unconfirmed ([Who already sells fast rounds to operators](issues/28-who-already-sells-fast-rounds-to-operators.md)).
- Crash games run in seconds but are house-banked RNG content, sold to licensed casinos through aggregators that require a supplier licence and a lab certificate ([How crypto operators buy game content](issues/27-how-crypto-operators-buy-game-content.md)).
- Social, livestream, esports and sports outcomes either cost money, bar betting use under their data licences, or can be produced by the bettor inside 30 seconds ([Which events settle in 30 seconds without a person](issues/26-which-events-settle-in-30-seconds-without-a-person.md)).

The developer has the opposite problem. They are solo, part-time (about 10 hours a week), with $0 and no operator contacts. Their earlier efforts stalled with no payer. They need a product that one reachable **Payer** will pay for before it is built, and a route to that **Paid commitment** that fits five hours a week of outreach.

## Solution

**One payer:** Base token teams with at least one Base pool of ≥ US$100k liquidity and ≥ US$50k daily volume. Launchpads are dropped as a class, though Virtuals stays as one named target. Streamers and Vietnamese trading groups are a fallback distribution route, not payers.

**One product:** white-label, real-money **Round** markets on the payer's token. The payer deploys and owns the contracts, so the payer is the **Operator** and the **Liquidity provider**. Rounds run back to back. Each Round has a trading phase of 5-30 seconds, then a **Window** of 1-30 seconds with trading stopped. The payer sets both lengths per **Campaign**. Rounds overlap: a new one is trading while the last one's Window runs. Nobody reports results. Each Round settles itself from TWAP **Readings** taken from the payer's Base pool, and anyone, or a small bot, can call settle.

The pilot has two market types:

- **Up/down over the Window**, on the Speedrun AMM. The payer seeds each Round. **Players** buy and sell Yes (Up) and No (Down) during trading. The start Reading is taken when trading closes, so nothing about the outcome is known while trading.
- **Price threshold** and **market cap threshold** (pool price times total supply), on a pari-mutuel **Pot**. Players stake Yes or No and the winners split the pot. The payer puts a fixed **Opening stake** on both sides of every Round instead of AMM liquidity.

A payer-set **Stake cap** per player per Round stays below the cost of moving the pool price over the Window. The stake token is the payer's choice per Campaign: its own token, ETH or USDC. A **Tie** refunds. An **Unmatched** pot refunds. The developer takes no cut of stakes and charges no trading fee.

Players use a payer-branded Round page that the developer hosts during the pilot. It is linkable and embeddable from X, Telegram and Discord, and it is handed over to the payer after the pilot.

**The deal:** a flat **US$300 per 7-day pilot Campaign**, paid upfront in USDC or ETH. One step down to US$200 is allowed. The floor is a US$100 non-refundable deposit. A signed LOI counts only if it names a price of at least US$300 and a start date. Free pilots never count.

**The outreach route:** English-first DMs to about 25 qualifying token teams, AXIS Robotics first. Telegram DM first, then X DM, then the partnership channel. The first message is under 80 words, pitches engagement and volume, links the demo and asks for a 15-minute call. There are 3 waves (8, 8, the rest) and at least 20 sends, each followed up once after 4 days. Pool numbers are re-pulled within 48 hours of each send. The first send is targeted for 2026-11-09, with a hard limit of 2026-11-16. Every contact is logged in the outreach log. The developer sends the messages and takes the calls. The agent finds contacts one wave ahead and keeps the log.

## User Stories

### Payer: deciding to buy

1. As a token team founder, I want a DM under 80 words that says what I get and what it costs, so that I can decide in one read whether to reply.
2. As a token team founder, I want to open a demo branded with my ticker, so that I can see what my holders would see before I agree to a call.
3. As a token team founder, I want a 1-minute video instead of a call if I'm busy, so that I can judge it without scheduling anything.
4. As a token team founder, I want a flat US$300 price for a 7-day pilot, so that I know my cost upfront and it fits a marketing budget.
5. As a token team founder, I want to pay in USDC or ETH, so that I can pay from the treasury I already hold.
6. As a token team founder who balks at the price, I want one lower offer, so that I can try it for less on the first pilot.
7. As a token team founder, I want to commit with a US$100 non-refundable deposit that comes off the pilot price, so that I can secure a slot before paying in full.
8. As a token team founder, I want a straight answer to "who is liable": I deploy and operate the contract, and the developer is a software vendor, so that I know where I stand.
9. As a token team founder, I want the pitch to say the developer takes no cut of my holders' stakes, so that I know the vendor isn't competing with my community for money.

### Payer: setting up a Campaign

10. As a payer, I want to deploy and own the Round contracts myself, so that I am the Operator and control the money.
11. As a payer, I want to pick the stake token (my own token, ETH or USDC) for each Campaign, so that the Rounds serve my own token's economy.
12. As a payer, I want to pick which of my Base pools the Rounds read from, so that settlement uses my deepest pool.
13. As a payer, I want to set the trading phase (5-30 s) and the Window (1-30 s) for each Campaign, so that I can tune how fast the Rounds feel.
14. As a payer, I want to set a Stake cap per player per Round, so that no player can stake enough to profit from moving my pool price.
15. As a payer, I want to choose which market types run (up/down, price threshold, market cap threshold), so that the Campaign fits my holders.
16. As a payer, I want to set the threshold levels for threshold Rounds, so that the questions are relevant to my token's price.
17. As a payer, I want to set the liquidity I seed into each up/down Round, so that I control how much I can lose to traders in each Round.
18. As a payer, I want to set a fixed Opening stake on both sides of every threshold Round, so that each pot opens with odds and rarely ends Unmatched.
19. As a payer, I want Rounds to start automatically, back to back, for the length of the Campaign, so that nobody has to open them by hand.
20. As a payer, I want the Round page to carry my token's name, ticker and branding, so that my holders see it as mine.
21. As a payer, I want a link and an embed I can post on X, Telegram and Discord, so that my community finds the Rounds where it already is.
22. As a payer, I want to stop a Campaign early, so that I can react if something goes wrong.

### Payer: during and after the pilot

23. As a payer, I want to see each Round's volume, player count and my liquidity's profit or loss, so that I can judge the pilot as marketing spend.
24. As a payer, I want to see how much stake volume the Campaign brought, so that I can compare it to the US$300 I paid.
25. As a payer, I want to withdraw my remaining liquidity at the end of each Round or Campaign, so that unused funds come back to my treasury.
26. As a payer, I want the Round page handed over to me after the pilot, so that I can keep running Rounds without the developer hosting.
27. As a payer, I want to buy a follow-up Campaign, so that I can keep Rounds running if the pilot worked.

### Player: trading an up/down Round

28. As a player, I want to see the current Round's question ("$TOKEN up or down in the next N seconds?"), so that I know what I'm betting on.
29. As a player, I want the chance shown as a headline in cents, with Up in green and Down in red, so that I can read the market at a glance.
30. As a player, I want a live price chart with a dashed line for the reference price, so that I can watch the price move.
31. As a player, I want a countdown to the end of trading, so that I know how long I have to place a trade.
32. As a player, I want to buy Up or Down shares and see what I'd win before I confirm, so that I know my upside.
33. As a player, I want to sell my shares before trading closes, so that I can exit if I change my mind.
34. As a player, I want the Stake cap shown beside the trade box, and trades above it refused, so that I'm not surprised by a failed transaction.
35. As a player, I want trading refused once the trading phase ends, so that nobody trades after the start Reading is known.
36. As a player, I want the start Reading taken when trading closes, not when the Round opens, so that nobody trades knowing how the Window began.
37. As a player, I want to see my position in the current Round, so that I know what I hold.

### Player: staking a threshold Round

38. As a player, I want to see the threshold (a price or a market cap) and the current value against it, so that I can judge the bet.
39. As a player, I want to stake Yes or No and see what I'd win now, so that I know my payout at the current split.
40. As a player, I want to be told that my payout shrinks if others join my side, so that a smaller win doesn't surprise me.
41. As a player, I want staking refused after the trading phase, so that nobody bets once the Window has started.
42. As a player, I want the payer's Opening stake settled like any other stake, so that the payer has no edge over me.

### Player: results and claiming

43. As a player, I want each Round settled from the pool's TWAP, not a single price, so that one trade can't decide the result.
44. As a player, I want both Readings stored onchain, so that I can check the result myself.
45. As a player, I want a link to each Round's settle transaction, so that I can see that it settled onchain and nobody chose the result.
46. As a player, I want to see the payer's liquidity pool balance on the page, so that I know winners can be paid.
47. As a player, I want a Tie on an up/down Round to refund exactly what I paid in that Round, so that an unchanged price costs me nothing.
48. As a player, I want a Tie or an Unmatched pot on a threshold Round to refund every stake, so that a one-sided or equal result never pays out.
49. As a winning player, I want to claim my winnings in one action, so that I get paid.
50. As a player, I want my claims never to expire, so that I can come back later.
51. As a player, I want claiming twice to pay nothing the second time, so that the contract can't be drained.
52. As a player, I want a table of recent Rounds with their results, so that I can see the game is running and settling.
53. As a player, I want the next Round to open while the last one's Window runs, so that I always have a Round to trade.

### Anyone: settling

54. As anyone, I want to call settle on any Round whose Window has ended, so that settlement never waits on the payer or the developer.
55. As anyone, I want settle to be refused before the Window ends, so that no Round settles early.
56. As anyone, I want a Round that can't get a valid Reading to refund every stake, so that a pool or sequencer outage never forces a guessed result.

### Developer: selling the pilot

57. As the developer, I want a list of qualifying token teams with their pool address, liquidity, volume and date checked, so that I only pitch payers that fit the bar.
58. As the developer, I want each target's pool numbers re-pulled within 48 hours of the send, so that I skip anyone who has dropped below the bar.
59. As the developer, I want the founder or BD lead found from first-party sources one wave ahead of each send, so that every message goes to a person where one is named.
60. As the developer, I want drafted messages, follow-ups and standard answers, so that each send takes minutes.
61. As the developer, I want the demo to rebrand by URL, so that each prospect sees their own ticker.
62. As the developer, I want one row per contact in the outreach log (pool, channel, wave, dates, reply, objection, amount, status), so that I can apply the kill rule on real numbers.
63. As the developer, I want the second wave's message revised from first-wave replies, so that the pitch improves as I learn.
64. As the developer, I want the fallback list used only if the first 20 sends get no reply within 2 weeks, so that my outreach hours go to payers first.
65. As the developer, I want a trading-group deal to count only if a qualifying token team is behind it, so that a promoter's interest isn't mistaken for a Paid commitment.

### Developer: delivering the pilot

66. As the developer, I want a deploy script the payer runs from its own wallet, so that I never hold the contract or the stakes.
67. As the developer, I want a small settle bot I can run during the pilot, so that Rounds settle on time even when no player calls settle.
68. As the developer, I want to host the branded Round page during the pilot, so that the payer has nothing to set up.
69. As the developer, I want to hand the page over as a static build plus config, so that the payer can host it after the pilot.

## Implementation Decisions

### Roles and money

- The payer deploys both contracts and is their owner. The payer is the Operator and the Liquidity provider. The developer has no privileged role in any contract.
- The Oracle role from the Speedrun contract is removed. Each Round settles from Readings. There is no `report`.
- One stake token per deployment, fixed at deploy: the payer's ERC-20, USDC, or ETH. Every amount, including the Stake cap, Opening stake and seeded liquidity, is in that token.
- The developer takes no cut and there is no trading fee. A fee share can follow a Paid commitment. It is not in the pilot.
- The payer's profit or loss on seeded liquidity is its marketing spend. The page and the pitch never call the payer "the house" ([What TAPL teaches the pitch](issues/36-what-tapl-teaches-the-pitch.md)).

### Round timing (both contracts)

- Campaign settings are fixed at deploy, or by the owner between Rounds: trading phase 5-30 s, Window 1-30 s, Stake cap, pool address, Campaign end time.
- A Round's phase is derived from time and state: Trading → Window → Awaiting settlement → settled (Up/Yes, Down/No, Tie, Unmatched) or refunded. No transaction is needed to move a Round between phases.
- Rounds are keyed by id and their start times follow the schedule. A new Round's trading phase runs while the last one's Window runs, so the next Round opens on schedule without anyone calling open. Whether a Round exists before its first trade, or is created lazily by its first trade, is a build call.
- Time is wall clock for the payer. Under the hood, Readings are pinned to blocks. Base blocks are 2 s today. Windows under 2 s wait for 200 ms blocks on Base mainnet (Denim, targeted Nov 2026, unverified). The demo uses 2-30 s.

### Readings

- A Reading is a TWAP of the payer's Base pool over a short lookback, pinned to a block. It is never a single instant's price. The lesson is Polymarket's move to a 60-second Chainlink TWAP after a snapshot attack.
- The start Reading is pinned when trading closes. The end Reading is pinned when the Window ends.
- The market cap is the Reading price times the token's total supply at the end block.
- The two contracts share one Reading module. Which pool types it reads (Uniswap v3/v4 or Aerodrome observations) and the shortest usable lookback at 2 s blocks must be confirmed first.
- If no valid Reading can be formed by a deadline after the Window ends, the Round refunds every stake. This is the outage rule carried over from creator feed markets.

### UpDownRounds (the Speedrun AMM, adapted)

- Built from the PredictionMarket AMM: Yes/No shares, the LP role, buy and sell quotes. Each Round is its own share book inside one contract, not a deployed contract per Round.
- The payer seeds each Round's liquidity from a pre-funded balance in the contract. Whether there is one seed size per Campaign or one per Round is a build call. Unused and remaining liquidity is withdrawable by the owner after settlement.
- Buy and sell are allowed only in the trading phase. A buy that takes the player's stake in the Round above the Stake cap reverts.
- Settle: Up if end Reading > start Reading, Down if lower, Tie if equal at the Reading's precision.
- **Tie:** each player is refunded exactly what they paid in that Round. The contract must track each player's net paid per Round, meaning buys minus sell proceeds, floored at zero. That floor is a build detail to confirm.
- Winning shares redeem at the Payout. Losers get nothing.
- The AMM is used only for up/down. On a threshold it reprices only on trades, so a bot that sees the pool cross the line buys the already-won side and drains the payer ([ADR 0003](../../docs/adr/0003-creator-markets-use-a-pari-mutuel-pot.md), [ADR 0004](../../docs/adr/0004-paid-fast-rounds-are-real-money-white-label-markets.md)).

### ThresholdPots (the pari-mutuel pot)

- Each Round is a Pot on one question: will the price be above X, or will the market cap be above Y, at the end Reading. The payer sets the threshold per Round, or a rule for it, such as an offset from the start Reading. That choice is a build call.
- The payer's Opening stake goes on both sides of every Round, drawn from a pre-funded balance. It is settled like any player's stake.
- Players stake Yes or No only in the trading phase, up to the Stake cap. There is no selling.
- Settle: Yes if the end Reading is above the threshold, No if below, Tie if equal. If one side holds no stake at the end of trading, the Round is Unmatched and settles without a Reading.
- Winners are paid their stake × pot ÷ winning side's total, rounded down. Tie and Unmatched refund every stake. There is no fee.
- Head-to-head Rounds ("does $A beat $B") come later.

### Contract interface (both, names indicative)

- Player: `buy` / `sell` (UpDownRounds) or `stake` (ThresholdPots), then `claim(roundId)`.
- Anyone: `settle(roundId)`.
- Owner (payer): fund and withdraw liquidity or Opening stakes, set Campaign settings between Rounds, set thresholds, stop the Campaign.
- Views: `phase(roundId)`, `currentRound()`, `quote(...)`, `positionOf(roundId, account)`, `claimable(roundId, account)`, both Readings, and the pool balance.
- Every refusal uses a custom error: over the Stake cap, outside trading, too early to settle, no valid Reading, nothing to claim, not owner.
- Claims never expire. Nothing is swept. Reentrancy protection and checks-effects-interactions on `claim`, `settle` and withdrawals.

### Stake cap and qualification

- The payer sets the Stake cap below the cost of moving the pool's TWAP across a Window. The cap shrinks with shorter Windows, because near-single-block Readings are cheaper to move. The developer supplies a rule of thumb from the pool's liquidity. Payers qualify on pool depth: ≥ US$100k liquidity and ≥ US$50k daily volume.
- Buys-vs-sells and pure-randomness Rounds are not offered. With money at stake they are trivial to rig.

### The Round page

- A payer-branded page in Kalshi's design language, as in the prototype: light theme, cents pricing, Yes/Up green and No/Down red, a chance headline, a price chart with a dashed reference line, a trade panel with the Stake cap and "To win", and a recent-Rounds table. Motion follows emil-design-eng.
- Branding (name, ticker, colours, logo) comes from config per payer, as the demo's `?brand=<TICKER>` does.
- Phase, quotes, positions and claimables are read from the contract views. Pot and AMM math are not recomputed in TypeScript.
- It shows the pool balance and a link to each Round's settle transaction ([What TAPL teaches the pitch](issues/36-what-tapl-teaches-the-pitch.md)).
- It is linkable and embeddable (an iframe for the payer's site, and links for X, Telegram and Discord). A Telegram mini app is a later upsell.
- The developer hosts it during the pilot and hands over the build and config afterwards.
- Prototype reference: `.scratch/paid-fast-rounds/prototype/PROTOTYPE-demo.html?v=player`, on the local branch `prototype/demo-payers-see` (commit b8318ff). Its AMM math is simplified and its feed is mocked. The contracts are the source of truth.

### Settle bot

- A small script watches for Rounds whose Window has ended and calls `settle`. The developer runs it during the pilot, and the payer can run it afterwards. It holds no privileges. It only pays gas.

### Outreach (the route to the Paid commitment)

- Run in [Run the outreach](../run-the-outreach/task.md), not in this build. The pitch drafts are in [Outreach pitch drafts](assets/32-outreach-pitch.md). The targets are in [The 30 qualified payers](research/34-the-30-qualified-payers.md) as amended by [Re-plan the outreach list](issues/35-re-plan-the-outreach-list.md). Contacts and replies go in `.scratch/run-the-outreach/outreach-log.md`.
- Legal questions get "you operate, check your own jurisdiction", never advice. The developer's accepted Vietnam risk is not mentioned in outreach.

## Testing Decisions

- **A good test** drives a contract only through its external functions and views. It asserts on observable results: token balances, `phase`, `quote`, `claimable`, stored Readings, emitted events and custom-error reverts. It never reads private storage or depends on internal helpers.
- **Two seams, in Foundry:**
  - **UpDownRounds:** buy and sell within the trading phase, the Stake cap (including cumulative buys), trading refused after the phase, the start Reading pinned at the end of trading, Up / Down / Tie outcomes, the Tie refunding net paid, redemption at the Payout, owner seed and withdraw, overlapping Rounds staying independent, and solvency: the contract never owes more than it holds (fuzz trade sequences).
  - **ThresholdPots:** the Opening stake on both sides, staking only in the trading phase, the Stake cap, price and market cap thresholds, Yes / No / Tie, Unmatched without a Reading, the pro-rata split rounded down, full refunds, double claims, and solvency (fuzz stake sequences).
- **Shared mock Base pool:** both seams use one mock pool that serves TWAP observations at chosen blocks and timestamps. Tests move time and blocks with `vm.warp` and `vm.roll`. It covers a Reading moved by a single-block spike (the TWAP must damp it), a missing observation (refund), and settle before the Window ends (revert).
- **Stake token:** each seam runs against both an ERC-20 stake token and ETH.
- **Prior art:** `packages/foundry/test/PredictionMarket.t.sol` (custom-error reverts, multiple actors, balance checks) and the Foundry test plan in [the creator feed markets spec](../creator-feed-markets/spec.md) for the pot.
- **Outside the seams:** the Round page, embed and settle bot get `playwright-cli` smoke runs against a local chain with the mock pool, and one run on Base Sepolia. No JS test runner is added.
- **Before the first pilot:** fork Base mainnet and read a real qualifying pool, to confirm the TWAP lookback and the Stake cap rule of thumb against real liquidity.

## Out of Scope

- Building anything beyond the demo before a Paid commitment.
- The developer as Operator, or holding stakes or contracts. The payer operates.
- Licensed operators (casinos, sportsbooks) and launchpads as payer classes. Trading groups and streamers as payers.
- Consumer distribution in the Farcaster feed, and creator-opened markets.
- Event domains other than Base pool prices and market caps: sports, esports, livestream, social, randomness, gas and block metrics.
- Head-to-head Rounds, a Telegram mini app, fee shares and revenue share on stakes.
- Sub-2-second Windows before Base mainnet runs 200 ms blocks.
- Legal clearance. The developer accepted the risk on 2026-10-26 and will handle legal later.
- Free pilots.

## Further Notes

- **Legal risk is known and accepted, not resolved.** [Legal exposure as a game supplier from Vietnam](issues/29-legal-exposure-as-a-game-supplier-from-vietnam.md) found that supplying a money-staked game carries accomplice risk for a Vietnam resident (Penal Code Arts. 17 and 322), and that Art. 6 can reach acts abroad. A US$20-200 lawyer consult with 7 prepared questions is the cheap next step.
- **Shortfalls going in:** no Vietnamese token team qualifies, 24 of 25 targets have no named BD lead, only 9 have a public Telegram, and several sit near the volume floor on a one-day snapshot ([The 30 qualified payers](issues/34-the-30-qualified-payers.md)).
- **To verify early in the build:** which Base pool types give usable TWAPs over a 1-30 s lookback at 2 s blocks; Base public RPC limits for the settle bot; whether Denim reaches mainnet; and how an expiry should work if a Round goes unsettled for a long time. The creator-feed **Expired** rule, a refund after 24 hours, is the default to carry over.
- **Still in the fog:** what the Paid commitment turns into, including whether the Base Builder Grant still fits. That waits on the outreach result.
- **A note on a recording:** if cold DMs get no clicks on the demo, record a short screen capture. That call belongs to [Run the outreach](../run-the-outreach/task.md).
