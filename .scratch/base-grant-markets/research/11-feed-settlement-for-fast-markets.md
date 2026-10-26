# Research 11: How a feed can settle a fast market safely

Ticket: `../issues/11-how-a-feed-can-settle-a-fast-market-safely.md`
Researched: 2026-10-24. All pages fetched that day. Sources marked (P) are first-party docs; (S) are secondary and need a recheck.

## Short answer

- For BTC/ETH, use a signed oracle price keyed to an exact timestamp (Pyth or Chainlink Data Streams), not an exchange trade price. For a points-only first test, a public exchange 1-minute candle (Coinbase, Binance, Kraken) is good enough and needs no key.
- Sports scores are the weak part. Free tiers are delayed or tiny (5-100 calls/day or min), and licensing is unclear. Treat sports as a later, paid-feed question.
- Pumpcade documents very little: one settler job at the deadline, a start value read at creation, "YES wins if final > starting, NO otherwise". Outages, refunds, ties and cutoff are not documented.
- Main attack defences: a hard Cutoff well before the window ends (or a delayed read point), a feed price rather than a trade price, a fixed read timestamp, and a staleness/confidence check.
- Outage and tie rules should be written down up front: tie -> refund; feed unavailable at read time -> bounded retry, then void and refund.

## 1. Price feeds for majors

### Pyth
- Hermes base URL `https://hermes.pyth.network`; endpoints `GET /v2/updates/price/latest?ids[]=` and SSE `/v2/updates/price/stream`. Since 2026-08-26 every Hermes request needs an API key (Bearer header), from pythdata.app/signup. On-chain contracts need no key. Rate limits and free-tier terms: not stated on pages read. (P) https://docs.pyth.network/llms-price-feeds-core.txt
- Price at an exact time: the best-practices page says delayed settlement with Pyth Core means fetching `GET /v2/updates/price/{publish_time}` and verifying with `parsePriceFeedUpdates()`. It does not document the time window, and I could not load the Hermes API reference (404 on hermes.pyth.network/docs/). Check the reference before relying on it. (P) https://docs.pyth.network/price-feeds/core/best-practices
- Pyth Pro (permissioned, API key): `POST /v1/price` returns price at a historical timestamp (Unix microseconds, raw integer); key must stay server-side. Channels at real-time, 50ms, 200ms, 1s. (P) https://docs.pyth.network/price-feeds/core/fetch-price-updates , https://docs.pyth.network/llms.txt
- Pyth Core update cadence "400ms" (marketing figure on the overview). Core prices now come from Pyth Pro; contracts accept an update when 3 of 5 router signatures verify. (P) https://docs.pyth.network/pro/how-pyth-works (via fetched summary; exact URL path uncertain)
- Proof: signed update plus Merkle proof, verified on-chain; Pyth Pro `verifyUpdate` checks signature and fee but not age, so the consumer must enforce freshness. (P) best-practices page above.
- Confidence: ~95% coverage interval; docs suggest pausing when conf/price exceeds a threshold (example 2%). Prices are stale if not updated recently; use `getPriceNoOlderThan`. (P) llms-price-feeds-core.txt
- Anyone can choose which signed update to submit, so the contract must pin a timestamp (round up to the channel interval and require the update's timestamp to equal it) to stop submitter cherry-picking. (P) best-practices page.

### Chainlink Data Streams
- Pull-based; "sub-second" latency via WebSocket. Reports are DON-signed and verified by the Verifier contract. (P) https://docs.chain.link/data-streams/architecture.md
- REST: base `https://api.dataengine.chain.link` (testnet `api.testnet-dataengine.chain.link`). `GET /api/v1/reports?feedID=&timestamp=` returns one report at a timestamp; also `/reports/latest`, `/reports/bulk`, `/reports/page`. Each report has `validFromTimestamp` and `observationsTimestamp` (seconds), so a report covers a span, not an instant. Auth is HMAC headers (SDKs handle it); 429 on rate limit, limits not listed. (P) https://docs.chain.link/data-streams/reference/data-streams-api/interface-api.md
- Access: "self-serve, no sales call" signup at app.chain.link. Billing page says subscription model, mainnet pricing by contacting Chainlink, pay-per-verification deprecated. Free tier not mentioned (testnet endpoint exists). (P) https://docs.chain.link/data-streams/reference/data-streams-api.md , https://docs.chain.link/data-streams/billing.md
- I could not load the "report timestamps" concept page (404), so the rule when no report exists at a moment is unconfirmed.
- Data Feeds (push, heartbeat/deviation) are too coarse for minute markets; I did not verify their heartbeat values. Not recommended.

### Exchange APIs (offchain, no on-chain proof)
- Coinbase Exchange candles: granularity 60s supported, max 300 candles per call, appears public (no auth). (P) https://docs.cdp.coinbase.com/exchange/reference/exchangerestapi_getproductcandles
- Binance spot `GET /api/v3/klines`: intervals 1s, 1m ..., startTime/endTime in ms, limit up to 1000, weight 2; klines identified by open time. Terms on redistributing data not found. (P) https://developers.binance.com/docs/binance-spot-api-docs/rest-api/market-data-endpoints
- Kraken `GET /public/OHLC`: public, 1-minute interval, last 720 candles only, last entry is the uncommitted current candle. (P) https://docs.kraken.com/api/docs/rest-api/get-ohlc-data
- Proof: none cryptographic. Only "we read this candle from this URL"; keep the raw response and URL in the settlement record. Fine for points.

### Recommendation for a points-only test
Settle on a 1-minute candle close (or a fixed-timestamp oracle price) from one primary source, with one named backup source, and store the raw response. Move to Pyth/Chainlink only when real value or onchain settlement arrives.

## 2. Sports scores and live events

All numbers below for football-data.org and balldontlie and TheSportsDB come from first-party pages where noted; API-Sports figures are secondary because the page returned 403.

| API | Free | Paid / live | Notes |
|---|---|---|---|
| football-data.org (P) https://www.football-data.org/pricing | 12 competitions, 10 calls/min, scores delayed (length not stated) | EUR 12/mo "Free w/ Livescores": live scores, 20 calls/min; up to EUR 199 | Commercial terms not on pricing page |
| TheSportsDB (P) https://www.thesportsdb.com/documentation | 30 req/min | Premium 100 req/min incl. livescores; price not on page | Terms at /docs_terms_of_use.php not read. Secondary sources (S): $9/mo Patreon, 2-minute live updates, community-contributed data |
| API-Sports football (S) via search | 100 req/day | Pro $19 for 7,500/day; live updated every 15s per their homepage | Page itself blocked (403); recheck |
| balldontlie NBA (S) via search | 5 req/min, no box scores | GOAT $39.99/mo for live box scores | Not confirmed on the first-party page |

Findings:
- Free tiers cannot poll a live game for a 1-30 minute market. 5-10 calls/min and delayed scores break the "one event, minutes" shape.
- Delay is the main risk: a member watching a TV stream sees the goal before the feed does. A feed delay of 15s to minutes makes last-minute betting exploitable unless Cutoff is placed well before the end.
- Most sports markets are not "price at time T". They are "who scores next" or "winner at full time", which end at an unpredictable moment. That does not fit a fixed 1-30 minute window. Better fit: "score at minute X" or "total after 10 minutes" using match clock.
- Licensing: none of the first-party pages read state redistribution or display terms. Unconfirmed; read each provider's terms before use. Official league data (Sportradar, Genius) is sold under enterprise licences; I did not research it.

## 3. How Pumpcade settles

Facts from docs (P), https://docs.cade.market/ pages (index.md, mechanics/automatic-resolution.md, mechanics/parimutuel-markets.md, usage/creating-markets.md, usage/placing-predictions.md, beta-onboarding.md):
- Solana, parimutuel. Durations 1, 5, 10, 30 minutes. Beta market types: token market cap, Polymarket YES odds, Kalshi YES odds.
- A settlement job is scheduled for the deadline at market creation. At the deadline a "settler service" fetches the outcome from the Pump.fun / Polymarket / Kalshi API, picks the winner, and submits an on-chain transaction.
- Start value recorded at market creation (starting market cap). Winner rule: "YES wins if final > starting, NO wins otherwise."
- Predictions are final, no cancel or modify. 1% fee. Time weighting: full 1.0x for the first 10% of the duration, then falling to 0.2x. Production markets need at least one participant on each side to execute; beta does not.

What it leaves open (not documented; my gaps, not necessarily Pumpcade's):
- Outage: nothing on API down, settler down or retries.
- Start value: taken at creation, not at the first moment bets open. If the market opens later than creation, bettors see a moving number. Timestamp and source of the start read are not specified.
- Ties: not stated. By the wording, equal final and start means NO wins (inference from "NO wins otherwise", flagged as my reading).
- Cutoff: no pre-deadline cutoff is documented, so betting may run to the deadline.
- Refunds: none documented, other than one-sided markets in production being unable to execute.
- Who settles: single trusted settler, no dispute path.

## 4. Attacks on short windows and mitigations

| Attack | Does it work | Mitigation | Evidence |
|---|---|---|---|
| Last-second bet by someone who sees the live price before the feed | Yes, if bets are accepted up to the read time | Hard Cutoff before the read time, wider than feed delay plus a margin | Pyth best-practices says assume adversaries "see price changes a short time before the protocol does" and recommends delayed settlement (P) |
| Pumping a thin token / spoofing a thin market | Yes for small caps | Restrict to majors (BTC/ETH); use an aggregated feed price (median across publishers), not a single venue's last trade | Pyth aggregate = median of publishers (P) https://docs.pyth.network/pro/understanding-price-data |
| Feed delay / stale price | Yes | Pin the read timestamp; reject updates older than a threshold; check confidence; note that submitters choose which signed update to submit | Pyth best-practices (P) |
| Settler picks a convenient moment | Yes with one settler reading "now" | Settle on a pre-declared timestamp, not "when the job runs"; store the raw response | Design inference |
| Candle still forming | Yes | Only read a closed candle (Kraken's last entry is uncommitted) | Kraken docs (P) |
| Several accounts per person in a group | Not a feed issue | Out of this ticket (map "Not yet specified") | |

What works best here:
1. Hard Cutoff before the window ends. A stake placed after the start value is read but before the end gives an informational edge. For a 5-minute market, closing betting at, say, 50-60% of the window (Pumpcade-style time weighting also discourages late bets) is a design decision for the window ticket.
2. Feed price rather than trade price. For majors the aggregated oracle price is far harder to move than one venue's last trade.
3. Read at a pinned timestamp, with the start and end values both from the same source and both stored.

## 5. Outage and tie rules

Nothing authoritative to cite on conventions, so these are recommendations that fit the reused stake model (stakes returned when nothing settles):
- Tie (final equals start at feed precision): refund everyone. Pumpcade's implicit "NO wins" favours one side and is unfair. Alternative: define by feed precision and round to a fixed number of decimals before comparing, then refund exact equality.
- One-sided pot (nobody on the other side): refund. Pumpcade production requires both sides.
- Feed unavailable at read time: retry the same pinned timestamp for a bounded period (suggest 2-5 minutes), switch to the named backup source only if declared in the market rules; if still nothing, void and refund. Do not extend the window: extending after the price is visible lets someone bet knowing more.
- Bad data (stale, wide confidence, publisherCount low, market closed): treat as unavailable.
- Sports: if the event is delayed, abandoned or the feed lacks a final, void and refund.

## Uncertain or unverified
- Hermes `/v2/updates/price/{publish_time}` details, Hermes free tier and rate limits (reference page 404).
- Chainlink report timestamp semantics when no report exists; pricing figures.
- API-Sports first-party pricing (403); balldontlie first-party pricing; TheSportsDB terms of use; any provider's redistribution licence.
- Exchange API terms of use for using their data to settle a game.
- Pumpcade internals beyond the docs pages above; the OpenAPI spec (https://docs.cade.market/api-reference/openapi.json) was not read.
- Pyth "400ms" latency is a docs headline, not a measured end-to-end figure.

---

# Addendum (2026-10-24): onchain on Base mainnet

The map was redrawn to `.scratch/base-grant-markets/`. Gaps below. (P) = first-party docs.

## A. Pyth and Chainlink on Base

### Pyth contracts on Base
(P) https://docs.pyth.network/price-feeds/core/contract-addresses/evm
- Base mainnet: Pyth Pro `0xACeA761c27A909d4D3895128EBe6370FDE2dF481`; Pyth Core `0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a`; Pyth Core Compatible `0xbC16aee60f64864882BC6C4E428e148Fc0E272F5`.
- Base Sepolia: Pyth Pro `0xACeA761c27A909d4D3895128EBe6370FDE2dF481` (same); Core not listed; Core Compatible `0x5f52e4DBEA21f5b23523B6e20d50c29ae0a4EB83`.
- Which one to integrate (Core vs Core Compatible) is not explained on the page I read. Confirm before use.

### Reading the price at an exact timestamp (Pyth Core)
(P) IPyth.sol, https://raw.githubusercontent.com/pyth-network/pyth-crosschain/main/target_chains/ethereum/sdk/solidity/IPyth.sol
- `parsePriceFeedUpdates(bytes[] updateData, bytes32[] priceIds, uint64 minPublishTime, uint64 maxPublishTime) payable returns (PriceFeed[])` parses and verifies the update and returns the feeds only if each was published within [min, max]. It reverts on insufficient fee, invalid data, or no update in the range.
- `parsePriceFeedUpdatesUnique` is the same but requires the update to be the first one published in the range. Use this for a start/end price: without it a caller could pick any of several updates inside the window (the best-practices page warns submitters choose which signed update to include; https://docs.pyth.network/price-feeds/core/best-practices).
- Offchain, anyone fetches the update bytes for time T from Hermes `GET /v2/updates/price/{publish_time}` (see section 1; Hermes reference page unverified). Anyone can submit it, so settlement is permissionless: the contract only accepts bytes that the Pyth contract verifies and whose publish time falls in the window.
- Window choice is a design decision: a narrow window (e.g. T to T+1s) gives a precise price but may revert if no update lands in it, a case the outage rule must cover.

### Chainlink Data Streams on Base
- Base is listed as supported for Streams Trade (Automation-based onchain lookup). (P) https://docs.chain.link/data-streams/supported-networks.md
- Verifier proxy address for Base: NOT OBTAINED. The address table is rendered in the browser and absent from the markdown and llms-full text I could fetch. Read it at https://docs.chain.link/data-streams/supported-networks. Base Sepolia support also unconfirmed.
- Verification: the contract calls `VerifierProxy.verify(unverifiedReport, bytes(""))`, decodes `ReportV3`/`ReportV8`. The example does not check timestamps; the report carries `validFromTimestamp`, `observationsTimestamp` and `expiresAt`, and a production contract must check them itself and verify before expiry. (P) https://docs.chain.link/data-streams/tutorials/evm-onchain-report-verification.md
- Fetching the report for time T offchain: `GET /api/v1/reports?feedID=&timestamp=` (needs API credentials, so the keeper holds an account, unlike Pyth where anyone can fetch).
- Net: Pyth is the simpler fit for permissionless settlement; Chainlink needs a credentialed fetcher and a subscription.

### Who pays the update fee
(P) https://docs.pyth.network/pro/on-chain-fees
- Pyth Core: governance set the fee to zero on EVM (OP-PIP-128). Passing `msg.value = 0` works; `getUpdateFee` returns 0.
- Pyth Pro: 1 wei per verified update on EVM, paid by the caller as `msg.value`.
- The page does not say anything Base-specific. Practically, the settling transaction's sender pays gas; the contract can reimburse or let anyone call `settle`.
- Chainlink: no per-verification fee; billing is a subscription (so the cost sits with whoever holds the Data Streams account). (P) billing and verification pages above. Subscription price not published.

## B. Approximate cost per settlement on Base

Only the pieces below are sourced; the totals are estimates.
- Base fee floor 0.005 gwei (5,000,000 wei). The docs' own example: a 200,000-gas transaction costs about $0.002 at the floor with ETH at $2,000. Total fee = L2 execution + L1 data fee, and the L1 part is usually the larger. (P) https://docs.base.org/base-chain/network-information/network-fees
- Oracle fee: about 0 (Pyth Core) or 1 wei (Pyth Pro). Chainlink: subscription, not per call.
- ESTIMATE, not sourced: a settle call that verifies one Pyth update and pays out a pot would be on the order of 200k-400k gas, with calldata of about 1-2 KB for the signed update. That puts one settlement at roughly a cent or less at floor gas, rising if the base fee or L1 fee spikes. I did not find a gas benchmark for `parsePriceFeedUpdates`. Measure on Base Sepolia before quoting a number.
- Use `GasPriceOracle` at `0x420000000000000000000000000000000000000F` (`getL1Fee`) for an exact L1 figure. (P) same Base page.
- Two oracle reads per market (start and end) roughly doubles the oracle-related cost; the payout loop is separate and depends on the claim design (pull claims keep the settle tx cheap).

## C. Capturing the start value onchain at creation

Yes, with the same mechanism, and it removes Pumpcade's open question (start value read by a settler at creation with no documented time or source).
- At `createMarket`, the creator supplies Pyth update bytes; the contract calls `parsePriceFeedUpdatesUnique` with a window around the open time (e.g. [block.timestamp - N, block.timestamp]), stores `price`, `expo`, `publishTime`, and checks confidence. Betting opens only after that.
- The same call at the end (window [T, T+W]) gives the final price, so start and end come from the same feed and are both provable onchain.
- Residual attack (my analysis, not sourced): the creator can pick among updates in the start window (mitigated by `Unique` plus a narrow window) and the creator knows the price before betting opens. Fix by fixing the start timestamp in the market parameters (e.g. start = creation block time rounded), and by keeping the hard Cutoff.
- Pyth Pro best-practices suggest rounding to the channel interval and requiring the update timestamp to equal the rounded value; that gives exact-match semantics if Pro is used. (P) best-practices page.

## Still unverified
- Chainlink verifier proxy address on Base mainnet and Sepolia.
- Hermes timestamp endpoint parameters and rate limits; which Pyth contract variant (Core vs Core Compatible) is right for `parsePriceFeedUpdatesUnique` on Base.
- Measured gas for parse and settle calls on Base.
