# What TAPL teaches the pitch

Research for ticket 36. Not legal or investment advice. Date: 2026-10-26.

Labels: **sourced** (first-party page or source file, read on the date above), **sourced (secondary)** (search snippet or aggregator), **inferred** (my reading), **unverified** (not confirmed; do not act on it without checking).

## Summary

TAPL is a BTC/ETH/LINK tap-trading game with a conventional **offchain house**: bets are priced, matched, resolved and credited in a private backend. The chain only holds a pool of funds and receives 15-minute batch commitments (a Merkle root, a total, a cap). The "verifiable" claim on the hackathon page is stronger than the code in the contracts repo supports. It is a hackathon proof of concept (PoC) on a testnet with no stated users, no revenue, and no buyer. Nothing in it changes decision 30 or 32.

| Point | Finding |
|---|---|
| 1. Pricing / resolution / settlement | Offchain, by the app backend. Onchain: pool custody, a Merkle root per 15-minute batch, a price-integrity report, a daily solvency report. |
| 2. Who pays whom | Players lose to the house; LPs ("Be the House") hold the house side. The only stated edge is a 3-5% persona assumption in a spec. Nobody buys it as a product. |
| 3. Borrow or avoid | Borrow nothing structural. Avoid the "LP as the house" framing and the batched offchain design in the pitch to token teams. One idea to keep: a published solvency/pool-balance view. |
| 4. Traction | None claimed. Repos created 2026-03-07; Sepolia deployment; one contributor login; 0 stars. |

## 1. Method (sourced)

- Hackathon page `https://chain.link/hackathon/winners/tapl`, fetched 2026-10-26.
- Repo `tapl-chainlink/smart-contracts-cre` read through `gh api` and raw files: `README.md`, `contracts/README.md`, `deployments-v1.txt`, `contracts/src/{Settlement,PoolReserve}.sol`, `specs/jtbd.md`, `specs/cre-workflows/02-settlement-workflow.md`, `specs/demo-script.md`, `specs/CRE-CONTRACT-FIX-PLAN.md`. `PriceIntegrity.sol`, `LPDistributor.sol` and `Roles.sol` were only grepped.
- Same org, read lightly: `tapl-chainlink/backend` (README and file list) and `tapl-chainlink/frontend` (file list). I did not read their pricing code.
- Not done: no running of the app, no onchain reads of the Sepolia addresses, no contact with the team. The pricing engine ("thousands of simulations every 100 ms") is not in the contracts repo; I did not locate or read it.

## 2. What TAPL is (sourced)

Hackathon page: "TAPL — a tap trading platform where you tap a cell to predict crypto prices in real time. Verifiable via Chainlink CRE", listed as **1st | Prediction Markets**, Convergence: A Chainlink Hackathon (Feb 6 - Mar 8, 2026), created by "Sniper Man". Assets named: BTC, ETH, LINK. Links go only to the GitHub org, no live app URL.

The contracts repo README is blunter than the page: "Smart contract and Chainlink Runtime Environment infrastructure for the Tapl BTC tap-trading **proof of concept**." It states the repo "does not contain the app frontend or backend", and lists "Production readiness: Not targeted", "Mocked CCIP, simplified trader accounting, no upgrade path", "Security posture: PoC", "Trusted app API / CRE assumptions remain". The earlier skim (BTC/USDT, 5-second windows, $20 grid, offchain resolution, 15-minute batches, house-vs-LP) is **confirmed** against the README ("BTC/USDT tap-trading with 5-second windows and $20 grid bands").

## 3. Point 1: pricing, resolution, settlement (sourced)

**Pricing: offchain.** The page says a pricing engine "runs thousands of simulations every 100 milliseconds to calculate fair odds" and each bet "is instantly locked at the exact oracle timestamp with a frozen multiplier". No pricing code is in the contracts repo. `specs/jtbd.md` says the multiplier "updates every second (Chainlink Data Streams)" and "snapshots at lock". The multiplier is therefore a server-side number, not a contract-computed one.

**Resolution: offchain.** `specs/jtbd.md`, "Settle" story: "Off-chain (backend hot path): receive bet, lock multiplier, evaluate OHLC touch, credit in-app balance, write WAL + Ledger entries". A bet wins if a 1-second OHLC candle's high or low touches the band. The root README: "Fast gameplay and bet resolution remain offchain. Onchain responsibility is verification and batch commitment, not order matching."

**Settlement: a 15-minute commitment, not a payout.**
- `specs/cre-workflows/02-settlement-workflow.md`: a cron CRE workflow fetches the app API's pending batch (deposits, withdrawals, settled win/lose orders), canonicalizes it, computes a Merkle root, `totalPayout` and `withdrawableCap`, and calls `Settlement.commitSettlementBatch(batchId, merkleRoot, totalPayout, withdrawableCap, windowStart, windowEnd)`. Input is "from app API"; CRE recomputes from what the app supplied, so the app is still the source of truth.
- `Settlement.sol`: `_commitSettlementBatch` only stores the struct, rejects duplicate IDs and bad windows, and emits an event. It does not move funds, verify any proof, or update any user balance. `markPaid` is owner-only bookkeeping. A grep for `MerkleProof` or `verify(` across `Settlement.sol`, `PoolReserve.sol` and `PriceIntegrity.sol` returns 0. The page says CRE "immediately updat[es] the user's withdrawable balance"; the contract code does not do that, and the workflow spec says per-account `setWithdrawable` updates are "intentionally out of this workflow".
- `PoolReserve.sol`: `depositTrader` and `claimTrader` carry the comments "(demo: no balance tracking)" and "(demo: no withdrawable check)". `claimTrader(amount)` transfers `amount` of the asset to `msg.sender` with no balance check, so in this deployed code any caller could drain the vault. The withdrawal gate the specs describe ("withdrawals are capped to the latest committed amount") is not enforced in this contract.
- `contracts/README.md`: "No on-chain candle verification (trusted CRE reporter)". It also warned the deployed contracts "cannot receive reports from CRE workflows" without a fix (`specs/CRE-CONTRACT-FIX-PLAN.md`). The later root README says the receiver template is in place; I did not verify the live contracts accept reports.

**Onchain versus offchain, summary (sourced):**

| Piece | Where |
|---|---|
| Odds, multiplier, bet lock, win/lose, balances, ledger | Offchain, app backend |
| Price feed used for settlement | Chainlink Data Streams (per specs); compared to the app's feed every 15 minutes |
| Price-integrity report (deviation vs Chainlink reference) | Onchain, 15-minute cron |
| Settlement commitment (Merkle root, totals) | Onchain, 15-minute cron |
| Solvency report (balance vs liability) | Onchain, daily cron; liability figure supplied by the app API |
| Pool custody, LP shares | Onchain (`PoolReserve`) |
| Per-bet payout | Not onchain |

Contrast with ticket 30: our Round settles itself from pool TWAP Readings onchain, with no operator-supplied number. TAPL's trust model is "the operator publishes a signed summary and Chainlink checks it is consistent with an oracle", which is weaker than ours (inferred).

## 4. Point 2: who pays whom, and who buys it (sourced / inferred)

- **Players pay the house.** `specs/jtbd.md`, persona "Degen Dan": "High volume, accepts 3-5% house edge for speed and UX". This is a persona assumption in a spec, not a measured or published rate. Payouts are set by the multiplier, which "the closer a cell is to the current price, the lower the payout".
- **LPs are the house.** Page: users can "Be the House" by depositing tokens into a pool "to mint LP shares and earn yields based on the platform's mathematical edge". `specs/jtbd.md`: "LP returns are transparently tied to trader outcomes (zero-sum)", "LP is NOT guaranteed against losses". "LP Larry" expects "8-15% APY from trading fees". `PoolReserve.depositLP/withdrawLP` mint and burn shares against the pool's token balance.
- **Fee or sponsor:** none found. No fee parameter in `Settlement.sol` or `PoolReserve.sol`; no sponsor, partner or customer is named in any file I read.
- **Does anyone buy it as a product?** No. It is a consumer game with its own pool, built for a hackathon track. No B2B or white-label offer, pricing, or customer appears in the page, README or specs. Inferred: TAPL has no payer in the sense of ticket 30; its "customers" are players and LPs of its own house.

## 5. Point 3: borrow or avoid in the pitch (inferred, from the sourced facts above)

**Avoid "LP as the house" in the pitch to token teams.**
- In ticket 30 the payer is the Liquidity provider and absorbs P&L as marketing spend. TAPL's version is a zero-sum house where LPs take real tail risk and are told they are not protected. Putting "be the house" in front of a token team makes the US$300 ask sound like a request to fund a casino bankroll. Ticket 30 already frames the payer's stake as an Opening stake and a marketing cost; keep that.
- Their own spec concedes the framing needs CVaR limits, skew and a solvency monitor to be defensible. We have a pari-mutuel pot for thresholds precisely so the payer is not the counterparty. That is a differentiator to state, not to hide.

**Avoid the batched, offchain-resolved design.**
- It is a trust-me backend with an audit trail. Ticket 30's selling point is that the Round settles itself from onchain pool Readings. Adopting a 15-minute commitment would erase that and would also break the 1-30 second Window.
- Their repo shows the failure mode: the headline says "every bet, outcome ... permanently recorded on-chain", the code stores a Merkle root and an unguarded `claimTrader`. A token team's engineer will read the contract. Claim only what our contract does.

**Worth borrowing (small):**
- A public solvency or pool-balance view (their Proof of Reserve idea) as a proof point on the payer-branded Round page. It is optional and does not change scope (inferred).
- Their "verify link" per outcome (bet history with a link to the settlement) maps to a link from each Round to its settle transaction. Also optional.

**One audience note (inferred):** TAPL won a Chainlink-sponsored track by leaning on Chainlink CRE. That is a judging fit, not evidence that crypto projects pay for it. Do not cite it as social proof in outreach.

## 6. Point 4: traction, users, deployment (sourced)

- **Users / volume / revenue:** none claimed on the hackathon page, README, or specs I read.
- **Deployment:** Sepolia testnet. `deployments-v1.txt` and the root README give Sepolia addresses (Roles `0x23B8F26A359C036C69BfaF28AE765D3d975f055d`, PoolReserve `0x0b7400e10fd916A7B9eEe8981532aF9f38255bAf`, Settlement `0xEDD391FDa28993287Df301485ABF72865dee5050`, and others), with the asset a USDT on Sepolia, and owner/reporter/settler/strategist/distributor all set to the same address. `contracts/README.md` says the target network is "Base Sepolia", which conflicts with the Sepolia deployment record; the broadcast folder is chain 11155111 (Sepolia). I did not read the contracts onchain.
- **Repo activity:** `smart-contracts-cre` created 2026-03-07, last push 2026-03-08, 0 stars, one contributor login (`aa-sniperman`). The `backend` and `frontend` repos were both created 2026-03-07 and last pushed the same day. The org has no description or website. No later activity found. Mainnet: no evidence.
- **Tests:** `contracts/README.md` claims 117 passing Foundry tests; not run by me.

## 7. Does this change decision 30 or 32?

**No.**
- Decision 30 (token-team payer, white-label market, self-settling onchain Readings, pari-mutuel pot for thresholds, US$300 flat fee, payer as Operator and LP) is not contradicted. TAPL has no payer and no deal type to compare, and its design is the offchain-house model that decision 30 avoids on purpose.
- Decision 32 (the pitch is engagement and volume, "you own the contract", US$300 for 7 days, under 80 words) is not contradicted. The only adjustment worth making is a negative one: keep "LP as the house" and "bet on anything in a tap" language out of the drafts. Check `../assets/32-outreach-pitch.md` for the word "house" before the first send (I did not read that file).
- The open reference in decision 30 ("TAPL as a model alongside Pumpcade") is now identified and can be closed. Its useful content is the UX (grid, tap, frozen multiplier) and the proof-of-reserve idea, not the business model.

## 8. Gaps and unverified

- The pricing engine, order matching and any fee logic are in a backend I did not read. Whether a house edge is built into the multipliers is **unverified**.
- The live demo, if any, was not found; the page links only to GitHub.
- Whether the Sepolia contracts accept CRE reports as deployed is **unverified** (README and the fix plan disagree).
- The `claimTrader` drain is read from source; I did not test it or check whether a later commit changed it (HEAD at fetch time; last commit 2026-03-08 "fix: readme").
- "Sniper Man" is the only person named; no company, funding or customer information was found.
- The hackathon judging criteria and prize amount were not checked.

## 9. Sources

- Hackathon page: https://chain.link/hackathon/winners/tapl (fetched 2026-10-26).
- Repo: https://github.com/tapl-chainlink/smart-contracts-cre, files listed in section 1 (read via `gh api` and `raw.githubusercontent.com`, HEAD, 2026-10-26). Repo metadata via `gh api repos/tapl-chainlink/smart-contracts-cre`.
- Org repos: https://github.com/tapl-chainlink/backend and https://github.com/tapl-chainlink/frontend (README and tree only).

## Resolution

(Proposed, not applied.)

TAPL is a hackathon proof of concept for a consumer tap-trading game on BTC, ETH and LINK, on Sepolia, with no stated users, revenue, customers or fee. Rounds are priced, resolved and credited offchain by the app backend; onchain it only holds a pool and receives 15-minute Merkle-root settlement commitments, a price-integrity report and a daily solvency report. The contracts do not verify proofs or move per-bet payouts, and `claimTrader` has no balance check. Players lose to a house of LPs ("Be the House"); the only edge figure is a 3-5% persona assumption. Nobody buys it as a product.

- Decision 30: unchanged. Close its open reference: "TAPL" is this project. Keep the self-settling onchain Readings and the pari-mutuel pot as differentiators.
- Decision 32: unchanged. Do not use "LP as the house" or batched offchain settlement in the pitch; do not cite TAPL's hackathon win as proof of demand. Check the pitch drafts for the word "house".
- Optional, no scope change: show a pool balance and a per-Round settle-transaction link on the Round page.
