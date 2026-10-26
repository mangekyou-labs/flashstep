# Which retro and builder grants fit a solo dev

As of 2026-10-25. Labels: [P] = first-party/primary page read directly; [S] = second-hand (news, aggregator, search snippet); [I] = my inference.

## Summary and first pick

**First pick: Base Builder Grant Program** (announced 2026-08-10, up to $5,000 plus GTM/product support). Base's own docs list "Prediction markets" first among its focus areas, so a prediction-market exclusion is not a risk here. First step is registering a Builder Code (free, base.dev). The weak points: it is application-based and "very selective", and the docs page says nothing on KYC, payout timing or cohort dates. Full anonymity is probably not workable (see caveats).

Key caveats:
- Most of the programs you named are dead or paused: Optimism Retro Funding is paused for at least 12 months [P]; Talent Protocol Builder Rewards wound down (final campaign ended 2026-07-27, ecosystem rewards end 2026-10-29) [P]; Chainlink Build moved to paid commercial agreements and its token rewards ended [P]. Telegram/TON requires the TON chain, so it does not fit a Base app [S/I].
- No program publishes usage thresholds, a sponsored-gas rule, or a farming filter for Base. Base Builder Codes rewards are still described only as "potential"; no payout has been published [P].
- Base's older retroactive grants (1-5 ETH) required W8/W9 tax forms [P, 2023 post], so a fully anonymous solo dev likely cannot collect. Pseudonymous-with-tax-forms is the realistic case [I].
- Nothing found says real-money prediction markets are excluded by any of these programs, and Base names them a priority area. No source on gambling carve-outs was found either way, so confirm with the program before building around it.

## Ranked table (expected payout per hour of solo work)

Hours and rank are my estimates [I]. Rank discounts the headline payout by how selective the program is.

| Rank | Program | Status late 2026 | Headline payout | Est. hours | Why this rank | Sources |
|---|---|---|---|---|---|---|
| 1 | Base Builder Grant Program (new) | Open, cohort-based; apply via form [P] | Up to $5,000 + GTM/product support, monthly feedback [P/S] | 4-8 (Builder Codes integration + form) | Prediction markets is the first listed focus area; needs a live product, building exclusively on Base. Selective. | [Base docs](https://docs.base.org/get-started/builders) [P]; [Base announcement on X](https://x.com/base/status/2086754553580355673) [S via search; page returned HTTP 402 to me] |
| 2 | Base retroactive Builder Grants (nominated) | 20+ cohorts since Mar 2024 [S]; Sept 2026 coverage suggests still active, not confirmed [S] | 1-5 ETH [P, 2023 post] | 1-2 (get nominated, post on X/Farcaster) | Near-zero application work, but you cannot apply, only get noticed or nominated. Needs W8/W9. | [grants.base.eth post](https://paragraph.com/@grants.base.eth/calling-based-builders) [P]; [CoinFabrik listing](https://www.coinfabrik.com/web3-grants/base-grants/) [S] |
| 3 | Farcaster Developer Rewards (verified mini apps) | Documented; docs page may be stale, no 2026 confirmation [P/S] | Weekly; size unpublished in what I read; based on usage and onchain transactions [P] | 1-2 (sign manifest `accountAssociation`) | Cheap one-time setup, automatic. Value unknown, may be small or ended. | [Farcaster mini app docs](https://miniapps.farcaster.xyz/docs/guides/publishing) [P] |
| 4 | Base Builder Codes rewards | Codes live since 2026-02-12; rewards "potential/future" only [P] | Unpublished | 1-2 (append ERC-8021 suffix) | Needed for rank 1 anyway; no payout yet. Free option value. | [Builder Codes docs](https://docs.base.org/apps/builder-codes/builder-codes) [P]; [Base Build on X](https://x.com/buildonbase/status/2022061762443640934) [S] |
| 5 | Coinbase Developer Platform (CDP) Founders Fuel / Builder Grants | Founders Fuel exists (credits); last cash round found was Summer 2025, $30K across 13 projects [S] | Up to $15,000 in CDP/Paymaster credits (not cash) [S]; past grants $3-5K per project [S] | 3-6 | Credits not cash; no 2026 grant round found. Requires CDP tool integration (Wallets, Onramp, x402, Paymaster). | [Founders Fuel](https://www.coinbase.com/en-mx/developer-platform/discover/launches/founders-fuel), [Summer 2025 grants](https://www.coinbase.com/developer-platform/discover/launches/summer-builder-grants) [S via search] |
| 6 | Base Batches 2026 (accelerator) | Running; terms conflict ($10K grant for top 15 teams and $50K investment for 3+, versus docs "$100K investment") [S/P] | $10K-$100K | 40+ (8-week program, demo day) | Large payout but heavy time and diligence; poor fit for a solo anonymous dev. | [Base Batches](https://www.basebatches.xyz/) [S]; [Base get-funded](https://docs.base.org/get-started/get-funded) [P] |
| 7 | Chainlink Community Grants | Rolling, no deadline [S aggregator] | Amounts not found | 10+ (Chainlink integration plus proposal) | Only worth it if you use Chainlink for resolution. Build is now commercial deals, not grants. | [Build evolution, 2026-06-26](https://chain.link/blog/build-program-evolution) [P]; [aggregator](https://grantedai.com/grants/chainlink-community-grant-program-chainlink-5ca5f4d9) [S] |

## Not available or not applicable

| Program | Finding | Source |
|---|---|---|
| Optimism Retro Funding (Onchain Builders) | Paused: "will not run for at least the next 12 months" (post dated 2026-01-08). OP Atlas shows a discontinuation notice for 2026-09-18 [S via search; I could not load the page]. For reference, S7 required 1,000 tx, 420 qualified (non-bot) addresses and 10 active days in 180 days; budget up to 8M OP; paid monthly; no per-project amounts; page silent on KYC, gambling and sponsored gas. | [OP Season 9](https://optimism.io/blog/season-9-from-experiment-to-organization) [P]; [S7 mission details](https://gov.optimism.io/t/retro-funding-onchain-builders-mission-details/9611) [P] |
| Talent Protocol / Base Builder Rewards | Wound down. Final campaign ended 2026-07-27; Ecosystem Rewards end 2026-10-29 with a final distribution. Company cites shrinking ecosystem budgets. Earlier rules: Basename + Builder Score 40+, weekly ETH. | [Talent post](https://paragraph.com/@talent/talent-protocol-5-years-building-for-builders) [P] |
| WalletConnect WCT Rewards for Base Builders | Needs a WalletConnect SDK integration, Basename, Builder Score 40+ (Talent-dependent). Started 2025-09-23; 11 weekly distributions, 1M WCT total, so likely over. | [WalletConnect](https://walletconnect.com/blog/wct-rewards-for-base-builders) [P] |
| Pyth grants | Only 2024 material found: community/research/developer grants, moved to Superteam Earn bounties. No 2026 info. | [Pyth blog](https://www.pyth.network/blog/pyth-ecosystem-grants-program) [S via search] |
| Telegram / TON grants | TON-chain only (2025 mini app migration ad credits, $100-$50K). Does not support a Base app. No 2026 terms found. | [crypto.news](https://crypto.news/telegram-takes-back-ton-inside-the-2026-takeover/) [S] |
| Base Creator Grants (up to $4,000, 2026-09-02) | For content creators (writers, streamers, educators), not app developers. | [crypto.news](https://crypto.news/base-launches-creator-grant-program-with-up-to-4000-for-creators/) [S] |

## Answers to the cross-cutting questions

- **Eligibility, shipped vs idea:** Base Builder Grant wants a live product, Base-exclusive [P]. Older Base grants accepted "early ideas or initial prototypes" [P, 2023]. Mainnet vs testnet: not stated; assume mainnet [I].
- **Identity / KYC:** Base 2023 grants required W8/W9 [P]. New program: not stated on the docs page. Talent/WCT: no KYC found, but wallet/Basename linking. Team size: no restriction in any source read.
- **Usage measured:** Base: Builder Code attribution of onchain activity [P], no thresholds published. Farcaster: app usage and onchain transactions [P]. OP (paused): tx count, qualified addresses, active days [P].
- **Payout size / frequency / lag:** Base grant up to $5K, cohort-based, lag unpublished. Farcaster weekly. OP monthly (when it ran). No published shipping-to-payout lag for Base.
- **Prediction-market exclusion:** None found. Base names prediction markets a focus area [P]. This does not cover store policy or jurisdiction law, which I did not research.
- **Sponsored gas / farming:** No source says whether paymaster-sponsored transactions count or are filtered. Builder Codes docs are silent on paymaster attribution and farming detection [P]. OP's rule excluded bots only [P]. Treat as unverified and ask Base.

## Open items

- Ask Base: KYC/identity, payout timing, whether a pseudonymous entity is acceptable, and whether real-money prediction markets pass compliance review.
- Check the live Farcaster rewards page (farcaster.xyz/~/developers/rewards) for current amounts.
- I could not load the Base announcement on X (HTTP 402) or the OP Atlas banner directly.
