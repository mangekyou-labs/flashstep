# Creator markets in the feed: testnet v1

Label: ready-for-agent
Status: **shelved 2026-10-25.** Superseded by [A business that pays for 30-second rounds](../paid-fast-rounds/map.md); kept as prior art for Pyth settlement and the pari-mutuel pot.

> **"Open a market on BTC or ETH in one tap, put in an opening stake, share it to the feed, and earn 2% of the pot when it settles. Nobody reports the result: Pyth does."**

Source: the closed map [Creator markets in the feed](map.md), in particular [Creator fee and pricing](issues/21-creator-fee-and-pricing.md), [How the in-feed flow looks](issues/23-how-the-in-feed-flow-looks.md), [How a feed can settle a fast market safely](issues/11-how-a-feed-can-settle-a-fast-market-safely.md), [Does Base App still run Farcaster mini apps](issues/24-does-base-app-still-run-farcaster-mini-apps.md) and [The launch plan](issues/22-the-launch-plan.md), plus [ADR 0003](../../docs/adr/0003-creator-markets-use-a-pari-mutuel-pot.md). Terms follow the **Creator feed markets** and **Group markets** sections of `GLOSSARY.md`.

Written 2026-10-25. Live by **2026-12-06** on Base Sepolia.

## Problem Statement

Group and friend betting products stall for two reasons: nobody creates the questions, and the product lives in a separate app people forget to open ([Why group betting products stalled](../group-markets/issues/09-why-group-betting-products-stalled.md)). Short crypto markets exist (Limitless on Base, Pumpcade on Solana), but the operator writes the questions and runs the settler, so traders have to trust them, and nobody runs creator-opened markets natively in the Farcaster feed ([Who already runs creator markets in the feed](issues/19-who-already-runs-creator-markets-in-the-feed.md)).

A Farcaster user who wants to bet "ETH is higher in 15 minutes" with their followers has nowhere to open that market, no reason to bother, and no settlement they can check for themselves.

## Solution

Anyone opens an up/down market on BTC or ETH from a Farcaster mini app. They pick the asset, a 5, 15 or 60-minute **Window**, and an **Opening stake** of at least 0.002 ETH split across Yes and No. Then they cast it. The cast shows a poster of the market. Tapping it opens a one-card mini app where anyone stakes Yes ("higher") or No before the **Cutoff**.

The market is a pari-mutuel **Pot**. At the Cutoff staking stops and the start **Reading** is pinned. When the Window ends, anyone can settle by submitting the first Pyth price updates at or after the two pinned times. Winners split the pot minus the 2% **Creator fee**, which goes straight to the **Creator**. A **Tie**, an **Unmatched** pot, or a market nobody settles within 24 hours (**Expired**) refunds every stake with no fee. There is no admin, no protocol fee and no human reporter.

Everything runs on Base Sepolia with testnet ETH. A new Farcaster user gets a one-time drip of about 0.02 testnet ETH, so faucets don't decide whether people show up.

## User Stories

### Creator: opening a market

1. As a creator, I want to pick BTC or ETH, so that I open a market on an asset nobody in the feed can pump.
2. As a creator, I want to pick a 5, 15 or 60-minute Window, so that the market fits how long my followers will stay engaged.
3. As a creator, I want the question written for me from the asset and Window ("ETH higher in 15 min?"), so that I can't write an ambiguous question and nobody can open a fake one.
4. As a creator, I want to choose an Opening stake of 0.002, 0.005 or 0.01 ETH, so that the board never opens empty.
5. As a creator, I want to set the Yes/No split of my Opening stake anywhere from 1% to 99%, so that I can show my own view and set the opening payouts.
6. As a creator, I want opening to be refused below 0.002 ETH, or with a split that leaves a side empty, so that every market starts with both sides staked.
7. As a creator, I want a single "Open for X ETH" confirmation, so that opening takes one tap after the form.
8. As a creator, I want to see the Cutoff and the Window's end as clock times before I confirm, so that I know when my market closes and when it settles.
9. As a creator, I want a "Share to feed" action right after opening that composes a cast with the market's embed, so that sharing takes one step.
10. As a creator, I want the share cast to tag me as the creator, so that my followers know whose market it is.
11. As a creator, I want my Opening stake settled like any other stake, so that I get it back (or win or lose with it) under the same rules as everyone else.
12. As a creator, I want to stake more on either side after opening, so that I can back my view like any trader.
13. As a creator, I want the 2% Creator fee sent to me automatically when the market settles with a winner, so that I don't have to claim it.
14. As a creator, I want to see on the card the fee I was paid, so that I know what the market earned me.
15. As a creator, I want no fee taken on a Tie, Unmatched or Expired market, so that the refund rules are clearly fair to my stakers.
16. As a creator, I want to never be the one who reports the result, so that nobody can accuse me of settling my own market.

### Trader: staking

17. As a trader, I want to open the market from the cast in one tap, so that I can stake without leaving Farcaster.
18. As a trader, I want to see the question, the live price, each side's share of the pot and the pot size, so that I can judge the bet.
19. As a trader, I want to see the time left to the Cutoff, so that I know how long I have to stake.
20. As a trader, I want amount chips for 0.001, 0.005 and 0.01 ETH, so that staking is one tap after picking a size.
21. As a trader, I want each of the Yes and No buttons to show "pays X ETH · N.NNx now" for the chosen amount, so that I know what I'd win right now.
22. As a trader, I want to be told that payouts shrink if others join my side before the Cutoff, so that I'm not surprised by a smaller win.
23. As a trader, I want stakes below 0.0001 ETH refused, so that dust can't clutter the pot.
24. As a trader, I want to stake more than once and on both sides, so that I can add to or hedge my position.
25. As a trader, I want staking refused at or after the Cutoff, so that nobody can bet once the start Reading is known.
26. As a trader, I want to see my own stakes on each side, so that I know my position.
27. As a trader, I want to understand there is no selling before the Cutoff, so that I stake only what I'm happy to leave in.

### Anyone: the Window and settling

28. As anyone, I want the card to say staking has stopped once the Cutoff passes, so that I know the market is in its Window.
29. As anyone, I want to see the live price against the start Reading during the Window, so that I can watch the market play out.
30. As anyone, I want a "Settle (anyone can)" button once the Window ends, so that the market doesn't wait on the creator or the developer.
31. As anyone, I want settlement to accept only the first Pyth update at or after each pinned time, so that whoever settles can't pick a convenient price.
32. As anyone, I want both Readings stored onchain with their publish times, so that I can check the result myself.
33. As anyone, I want a Tie (end Reading equals the start Reading at feed precision) refunded, so that neither side gets an equal price.
34. As anyone, I want a market where one side holds no stake at the Cutoff to end Unmatched and refund, so that a one-sided pot never pays out.
35. As anyone, I want a market that nobody settles within 24 hours of the Window's end to become Expired and refund, so that money is never stuck.
36. As anyone, I want settlement refused when Pyth has no usable update in the band after a pinned time, so that a feed outage leads to Expired and a refund rather than a guessed price.
37. As anyone, I want the Window never extended, so that nobody can bet or settle knowing more than the rules allow.

### Trader: result and claiming

38. As a trader, I want the card to show the winner or the refund reason, the start and end Readings, and my claimable amount, so that I know the outcome.
39. As a winning trader, I want to claim my share of the pot minus the Creator fee in one tap, so that I get paid.
40. As a refunded trader, I want the card to say "no fee taken" and return my full stakes, so that I trust the refund.
41. As a trader, I want claims to never expire, so that I can come back any time.
42. As a trader, I want claiming twice to pay nothing the second time, so that the pot can't be drained.
43. As a losing trader, I want the card to show I have nothing to claim, so that I'm not left wondering.

### The cast embed

44. As a feed reader, I want the cast to show a poster with the question, a Yes/No bar with each side's share, the pot size and the Cutoff as an absolute UTC time, so that I see the market without opening it.
45. As a feed reader, I want the embed to show no countdown, so that a cached image never shows a wrong time.
46. As a feed reader, I want the button to read "Stake Yes or No", "Watch it settle" or "See result & claim" depending on the phase, so that I know what tapping will do.

### New user: wallet and drip

47. As a Farcaster user, I want to connect the wallet my Farcaster client gives me, so that I don't install anything.
48. As a new Farcaster user, I want about 0.02 testnet ETH sent to my wallet once, so that I can stake without finding a faucet.
49. As a new Farcaster user, I want the drip offered only when my balance is too low to stake, so that it doesn't get in the way.
50. As the developer, I want the drip limited to one per Farcaster FID and one per wallet, so that farming it means making Farcaster accounts.
51. As the developer, I want a daily cap on total drip, so that a burst of new accounts can't empty the hot wallet.
52. As a user outside Farcaster (Base App or a browser), I want to connect an injected wallet and sign in with Ethereum, so that the app still works there.

### Developer: running the launch

53. As the developer, I want the contract to have no owner, no admin and no upgrade path, so that the legal path's "immutable, no-admin contracts" holds.
54. As the developer, I want the contract verified on Basescan and open source, so that the grant application can point at it.
55. As the developer, I want a script that reports Taken markets per week and distinct wallets staking on markets they didn't create, so that I can check the target (20 a week and 15+ wallets, two weeks running) and the stop rule.
56. As the developer, I want the Pyth API key kept server-side, so that it never ships in the client.
57. As the developer, I want the gas cost of settling measured on Base Sepolia, so that I can quote it instead of the research estimate.

## Implementation Decisions

### Where it lives

- A new contract and new mini-app routes are built in this monorepo, next to the Speedrun challenge. The challenge contract, its tests and its pages are left untouched so the autograder keeps passing. Whether the Greenlight UI is reused is a build call, but the card follows the prototype.
- Chain: Base Sepolia only. `scaffold.config` targets Base Sepolia for the mini app.

### The feed-market contract (one contract, all markets)

- **One singleton contract holds every market**, keyed by an incrementing market id. It is not a factory deploying one contract per market. It is cheaper to open, there's a single address to verify and index, and there's one test seam. This departs from the map's early "Speedrun template plus factory" mapping, which was never a decision.
- **No owner, no admin, no pause, no upgrade, no protocol fee.** The Pyth contract address, the two price feed ids (BTC/USD, ETH/USD), the window lengths and every constant are fixed at deploy.
- **Constants:** creator fee 2% (200 bps); minimum Opening stake 0.002 ETH; minimum stake 0.0001 ETH; split 1–99% in whole percent; windows 5, 15, 60 minutes; settle band about 60 seconds; expiry 24 hours; maximum Pyth confidence 2% of price.
- **Market record:** creator, asset, window length, open time, Cutoff (open time plus window), end time (Cutoff plus window), Yes total, No total, a Taken flag, outcome, both Readings (price, expo, publish time) and the fee paid.
- **Timing:** staking runs from opening until the Cutoff, which is as long as the Window. The start Reading is pinned at the Cutoff and the end Reading at the Window's end.
- **Interface** (names indicative):
  - `open(asset, window, yesPercent)` payable. Requires the minimum Opening stake and both sides above zero. Records the Opening stake as the creator's own Yes and No stakes. Emits `MarketOpened`.
  - `stake(id, side)` payable. Requires at least the minimum stake and that the Cutoff hasn't passed. Adds to the sender's stake on that side. If the sender isn't the creator, the market is marked Taken. Emits `Staked`.
  - `settle(id, startUpdate, endUpdate)` payable for the Pyth fee. Allowed after the Window ends and before expiry. If one side is empty it ends Unmatched without reading prices. Otherwise both Readings are verified with `parsePriceFeedUpdatesUnique` on each band [pinned time, pinned time + band]. An update with confidence above the maximum is refused. The outcome is Yes if end > start, No if end < start, and a Tie if they are equal at feed precision. If there is a winner, the fee is paid to the creator. Emits `Settled`.
  - `claim(id)`. Pays the sender's winnings (their winning stake × (pot − fee) ÷ winning side's total, rounded down) or, on a refund, all their stakes. It zeroes them first and emits `Claimed`.
  - Views: `phase(id)`, `quote(id, side, amount)` returning the payout and multiplier if that side wins now, `stakeOf(id, account)`, `claimable(id, account)`, and the market record.
- **Phase** is derived from time and state, so no transaction is ever needed to move a market on: Staking → Window (Cutoff passed) → Awaiting settlement (Window ended) → Won Yes / Won No / Tie / Unmatched (settled) or Expired (24h after the Window's end with no settlement). Expired needs no trigger: `claim` refunds once the phase is Expired, and `settle` reverts.
- **Creator fee payout:** sent to the creator during `settle`. If the transfer fails, the fee is credited for the creator to pull instead, so a creator contract that rejects ETH can't block settlement.
- **Money rules:** claims never expire. Nothing is swept. Rounding dust stays in the contract. Use reentrancy protection and checks-effects-interactions on `claim` and `settle`.
- **Custom errors** for every refusal, such as below minimum stake, after Cutoff, too early to settle, expired, no usable update and nothing to claim.
- **Dependency:** Pyth's Solidity SDK (`IPyth`, `PythStructs`, `MockPyth`) is added to the Foundry package.

### Settlement data

- Price updates come from Pyth Hermes (`/v2/updates/price/{publish_time}`). Hermes has needed an API key since 2026-08-26, so a **server route** fetches the two updates for a market's pinned times, and the card's Settle button passes them to `settle`. Anyone else can fetch from Hermes with their own key and settle directly.
- The live price on the card comes from a server route that proxies Hermes' latest price. The card polls it every few seconds.
- Which Pyth contract on Base Sepolia to use (Pyth Pro or Core Compatible) must be confirmed first. It has to support `parsePriceFeedUpdatesUnique`. The research lists Pro `0xACeA761c27A909d4D3895128EBe6370FDE2dF481` and Core Compatible `0x5f52e4DBEA21f5b23523B6e20d50c29ae0a4EB83`, and has no Core address there.

### The mini app

- **Surface:** a Farcaster mini app (manifest plus `fc:miniapp` embed metadata). Wallets go through wagmi: the Farcaster mini-app connector inside Farcaster, and an injected connector plus Sign-In with Ethereum elsewhere. This keeps adding Base App later cheap.
- **Routes:** a market page per id (the card), an "open a market" page, an embed image route per market, and server routes for Hermes updates, the live price and the drip.
- **Card (the One-card ticket from the prototype):** one market and one card that changes by phase.
  - A status pill: staking open with time to the Cutoff, Window running, waiting for settlement, the winner, or Tie / Unmatched / Expired.
  - The question framed Yes/No, the live price, and the start and end Readings.
  - A split bar showing each side's share and the pot, with a note that winners split it minus the 2% Creator fee.
  - Amount chips and Yes/No buttons showing "pays X ETH · N.NNx now" from `quote`.
  - After the Window ends, "Settle (anyone can)".
  - The result and Claim on the same card. Refunds say "no fee taken", and the creator sees the fee they were paid.
  - No lobby, no list of markets and no claims inbox.
- **The card reads phase, quotes, stakes and claimables from the contract views.** It does not recompute pot math in TypeScript, which keeps the contract the single seam.
- **Open form:** asset, Window, Opening stake chips (0.002 / 0.005 / 0.01 ETH) and a 1–99 split slider, then "Open for X ETH", then "Share to feed" through the SDK's compose-cast action, tagging the creator.
- **Embed:** a 3:2 poster rendered from chain state with the question, the split bar, the pot and the Cutoff in UTC. It has no countdown. The single button title changes by phase. The image and title are cached by clients, so they are only as fresh as the last fetch.
- **Prototype reference:** the local branch `prototype/feed-market`, route `/prototype/feed-market?variant=ticket`. Its `model.ts` holds the phase list and the payout formula the contract must match:

  ```ts
  // from the prototype: payout if `side` wins after a new stake of `amount`
  payout = (amount / (sideTotal + amount)) * (pot + amount) * (1 - CREATOR_FEE)
  multiplier = (pot / sideTotal) * (1 - CREATOR_FEE)
  ```

### The drip

- A server route sends about 0.02 testnet ETH from a developer hot wallet. The key is kept in server env.
- It checks the caller's Farcaster FID through Quick Auth. It drips at most once per FID and once per address. The address must be the caller's connected Farcaster wallet. The card offers it only when the balance is below the cheapest stake plus gas.
- Dripped FIDs and addresses are kept in a hosted key-value store. A daily cap on drips bounds what can be lost.
- Outside Farcaster there's no FID, so there's no drip in v1.

### Launch metrics

- A script reads `MarketOpened` and `Staked` events and reports, per week: Taken markets, and distinct wallets that staked on a market they didn't create. That's enough to apply the target and the stop rule from [The launch plan](issues/22-the-launch-plan.md).

## Testing Decisions

- **A good test** drives the contract only through its external functions and views, and asserts on observable results: balances, `phase`, `quote`, `claimable`, emitted events and custom-error reverts. It never reads private storage or depends on internal helpers.
- **One seam: the feed-market contract's external interface, in Foundry.** Pyth is replaced by `MockPyth`, which builds signed-looking updates at chosen publish times. Time is moved with `vm.warp`. Prior art: `packages/foundry/test/PredictionMarket.t.sol` (custom-error reverts, multiple actors, balance checks).
- **What it covers:**
  - Opening: minimums, the split bounds and both sides above zero, the Cutoff and end times for each Window, the creator's stakes recorded, the event.
  - Staking: minimum, refused at and after the Cutoff, repeat and both-sides stakes, Taken set only by a non-creator.
  - Quotes: `quote` matches the payout actually claimed when no one else stakes, including the creator's own stake.
  - Settling: too early, after expiry, Yes and No wins, Tie at feed precision, Unmatched without updates, first-update-only (a later update in the band is refused), no update in the band, confidence too wide, the Pyth fee forwarded, and the fee paid to the creator (including a creator that rejects ETH, which falls back to a pull credit).
  - Claiming: winners' pro-rata split with rounding down, refunds return full stakes with no fee, Expired refunds with no settle call, double claims, losers get nothing, and the contract balance never goes below what's owed (fuzz the stake sequence).
  - No admin: the contract has no privileged functions.
- **Outside the seam:** the drip route, Hermes routes, embed image and card are checked by hand and with `playwright-cli` smoke runs against a local chain and Base Sepolia. No JS test runner is added in v1.
- **On Base Sepolia:** measure `settle` gas with two real Pyth updates before quoting a cost.

## Out of Scope

- Mainnet, the Vietnamese lawyer, the offshore frontend operator and geoblocking. Mainnet stays blocked until a lawyer clears it.
- Threshold questions, any asset other than BTC and ETH, Zora and Clanker coin markets, and settling on onchain state.
- Selling or exiting a stake before the Cutoff. Any AMM pricing.
- Markets settled by a person, disputes, group-only or private markets, and Telegram or Zalo surfaces.
- A lobby or market list, a claims inbox, notifications, a Base.dev listing and Base App store placement.
- Paid promotion, points and leaderboards.
- Applying for the Base Builder Grant, which happens after the target is hit.

## Further Notes

- The testnet ETH is worthless. v1 shows whether people open and stake on markets, not whether creators care about the fee, which waits for mainnet.
- **Abuse in v1:** BTC and ETH can't be pumped. Wash trading your own market only pays the fee back to yourself. Questions are built from asset plus Window, so fake markets can't exist, and the Opening stake prices out spam. The FID-gated drip keeps the "outside wallets" count honest. Revisit all of this when thresholds or coins arrive.
- **To verify early:** which Pyth contract on Base Sepolia supports `parsePriceFeedUpdatesUnique`; that `MockPyth` implements it; the Hermes historical endpoint's behaviour and rate limits under an API key; and Quick Auth's current API.
- **Launch:** the developer opens and casts at least one market a day and recruits about 10 creators from Farcaster crypto-trading channels and BuidlGuidl / Speedrun.
