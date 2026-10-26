# Legal path for real-money creator markets

Research for a decision record. Not legal advice; a lawyer in Vietnam and one in the chosen offshore/US-facing jurisdiction must confirm everything here. Date: 2026-10-25.

Labels: **sourced** = stated by a first-party or official document I fetched; **sourced (secondary)** = law-firm, news or aggregator report of a primary source I could not open; **inferred** = my reasoning.

## Summary

- Real money is the dangerous part, and where the developer sits matters more than which entity is used. A person physically in Vietnam who builds, hosts, profits from or promotes a real-money market is exposed under Penal Code Art. 321/322 whatever offshore wrapper is used (inferred). Art. 6 also lets Vietnam pursue its citizens for crimes committed abroad (sourced, secondary).
- No Vietnamese case found that prosecutes a pure contract author or a non-hosting developer. Cases found are operators and organisers (inferred from absence; search was shallow and English-only).
- The CFTC's 2022 Polymarket order hit the company that created, defined, hosted and resolved the markets; it said smart contracts do not change the rules (sourced). Polymarket's later US return came by buying a licensed exchange, not by being "decentralised" (sourced, secondary). A small builder cannot copy that route.
- Limitless runs through a Panama company with Panama law and a US/Canada/China trading block (sourced). Opinion is Hong Kong-based, no-KYC, US/China excluded (secondary). Melee is New York-based, on Solana, creator-fee model (secondary).
- **Cheapest structure that keeps the developer outside the likely liability:** (1) immutable, ownerless contracts with no fee or admin entitlement for the developer; (2) a frontend run by a separate foreign operator (Panama foundation, about $2-5k setup) in which the developer holds no shares, role, fees or keys, geoblocking Vietnam, the US and other bars; (3) the developer stays on points/testnet in anything they themselves run and is not paid from real-money flows. Detail under "Recommendation".
- If the developer is a Vietnamese citizen or lives in Vietnam, no cheap structure removes risk entirely; relocation or never touching the real-money side are the only clean fixes (inferred).

## 1. Vietnamese law: contract author versus frontend operator

Prior note (repo): points-only with no cash-out looks outside Art. 321/322; real money very likely illegal; Zalo betting groups prosecuted; mostly secondary sources (`.scratch/group-markets/issues/02-vietnam-law-for-points-and-real-money-group-markets.md`).

Statute (sourced, secondary; law-firm and translation sites, not the official gazette):
- Art. 321 gambling: stakes of VND 5m to under 50m, or under 5m for repeat offenders, carries a fine of VND 20-100m or up to 3 years; 3-7 years where stakes reach VND 50m, or where the internet, a computer or telecom network or an electronic device is used.
- Art. 322 organising gambling: organising 10 or more people at once with stakes of VND 5m or more (or 2+ simultaneous sessions) carries a fine of VND 50-300m or 1-5 years; 5-10 years where the internet or telecom networks are used or profit is VND 50m or more. Legal entities face a fine up to VND 3bn plus confiscation.
- Art. 6: Vietnamese citizens and commercial legal persons who commit crimes abroad "may" face liability under the Code (some translations say "shall"). Foreigners abroad: if the offence harms Vietnamese citizens' interests, or a treaty applies. A foreigner physically in Vietnam is covered by ordinary territorial jurisdiction (inferred).
- Whether prediction markets count as "gambling" is unresolved; guides report no specific rule and that Polymarket is not geoblocked for Vietnam (low-quality secondary). Inference: a money-staked market on an uncertain event falls within the plain wording of gambling, and a court is unlikely to accept "it is a forecasting tool".

Authors versus operators:
- I found no Vietnamese case charging someone solely for writing code. Relevant cases involve people who built and ran sites and resold points: the "Bong X9" case (reported over VND 4,000bn; a co-organiser redeveloped the site and sold points) and a 2025 Ho Chi Minh City trial of a family ring that built crypto-linked gambling sites, with sentences from 3 years suspended to 13 years (sourced, secondary: local press, Malay Mail/AFP). In both, the builder was part of the operation. A pure coder would likely be charged, if at all, as an accomplice ("giup suc"), which turns on knowledge and benefit (inferred). Needs a Vietnamese criminal lawyer.
- Frontend: hosting, domain, marketing and support are what police can see and look like "organising" (inferred). Vietnam's blocking tools target offshore sites rather than their authors: Decree 147/2024 (24-hour removal on request, then blocking); Decree 327/2026 reportedly lets security forces request suspension of payment accounts and wallets tied to illegal funds (secondary; snippets do not name gambling). The ministry identified 904 gambling-related sites in 2024 (secondary).
- Crypto: Resolution 05/2025/NQ-CP (9 Sept 2025) sets a five-year pilot, VND-denominated, licensed providers only; domestic users must use licensed providers six months after the first licence, with sanctions for knowingly using unlicensed ones (secondary). A Vietnamese user holding USDC on Base is in a grey zone at best (inferred). The Law on Digital Technology Industry took effect 1 Jan 2026 (secondary).

Immutable contracts specifically: nothing in Vietnamese law I found addresses them. US authority is mixed: the Fifth Circuit held Tornado Cash's immutable contracts were not sanctionable "property" (Van Loon v. Treasury, Nov 2024), yet in Aug 2025 a jury convicted Roman Storm of conspiring to run an unlicensed money transmitting business, deadlocking on the other counts (both sourced, secondary). Takeaway: immutability helps against "you control it", but a person who also runs the UI, relayers or fees is treated as the operator (inferred).

## 2. Common structures and costs

Cost figures come from provider marketing and vary widely (sourced, secondary: LegalNodes, Neolegal, Spindipper, Sovera, Complinexx). Treat as ranges.

| Structure | Setup | Annual | Time | Notes |
|---|---|---|---|---|
| Panama foundation | $1.8-5k | $1.2-5k (nominee directors) | about 1 week | Cheapest; Limitless uses a Panama company; nominees may not shield the real owner; banking reputation issues |
| BVI company | $1.5-4k | $1-2.5k (+$2-3k per nominee role) | days to 2 weeks | Fast issuer vehicle; no foundation regime |
| Cayman foundation company | $3.5-30k (quotes range wildly) | $2.5-25k | 2-6 weeks | Most credible with partners; economic substance rules; overkill here |
| Cayman foundation + BVI sub | about $8.5k+ | about $7k+ | weeks | Common token-launch pattern |
| Delaware LLC | low | low | days | Puts the project inside CFTC reach (Polymarket 2022 was a Delaware company); avoid for real money (inferred) |
| Frontend geoblocking | dev time plus geo-IP service | same | days | Reduces but does not remove exposure; VPNs; Polymarket's ToS bans VPN use (secondary) |
| Frontend run by someone else | $0 to legal review | $0 | n/a | Only helps if truly independent; a front for the developer does not count (inferred) |
| Vietnamese licence | n/a | n/a | n/a | No route found for this product (inferred) |

An offshore entity does not shield a founder who is owner, director, fee recipient and resident in Vietnam; Vietnamese authorities can reach the person, bank cards and local payment rails (inferred).

## 3. How comparable products are structured

- **Limitless (Base):** operator Street Chow Inc., a Panamanian company; Panama law; ICC arbitration in Panama City. Access barred in Russia, Belarus, Cuba, Iran, North Korea, Syria and occupied Ukrainian regions; trading barred in the US, "Republic of China", Ontario and Alberta. Vietnam is not listed, but users must obey local law. Anyone can create a market; the company can remove or modify it, designates oracle sources, and disclaims endorsement of user-created markets (sourced: https://docs.limitless.exchange/user-guide/terms-of-service). Reports also describe a Cayman-based US sub that filed with the CFTC (secondary).
- **Opinion (BNB Chain):** Opinion Labs, Hong Kong press datelines; no-KYC; about 150 countries with the US and China excluded; legal entity name not confirmed (secondary).
- **Melee (Solana):** New York-based; creators earn a share of trading fees; whitelisted creators in beta; $3.5m seed led by Variant (secondary). Entity and terms not confirmed.
- **Polymarket:** 2022 CFTC order against Blockratize Inc. (Delaware): off-exchange event-based binary options treated as swaps; $1.4m penalty; wind-down of non-compliant markets; "regardless of the technology used"; penalty reduced for cooperation; the order says the company created, defined, hosted and resolved the contracts (sourced: https://www.cftc.gov/PressRoom/PressReleases/8478-22). The international site is now run by Adventure One QSS Inc. (Panama) (secondary). July 2025: DOJ and CFTC reportedly closed probes; Polymarket bought QCEX (about $112m, licensed exchange and clearing house); a CFTC no-action letter followed in Sept 2025 (secondary). Lesson for a small builder: the penalty was modest and aimed at the company controlling the markets; the durable fix was expensive licensing, not code (inferred). A small builder avoids this by serving no US users and not being the controlling entity.

## 4. Do market creators take legal risk?

- Permissionless creation puts creators in the chain of "organising" a market (inferred). Whether a user who proposes a market on a platform counts as an offeror under US law is untested; I found no authority.
- In Vietnam, a creator who seeds a market with money and invites 10+ people to stake could fit Art. 322 as organiser even if the platform is offshore; the thresholds (10 people, VND 5m) are low (inferred). Creators who also earn fees are worse placed than one who only posts a question.
- A platform ToS clause disclaiming user-created markets protects the platform, not the creator (inferred).
- Seeding liquidity: no source found; flag for the lawyer.
- Design implication: the developer's own accounts should never create or seed markets; creators should see terms, a geoblock, and a warning that creating markets may be unlawful where they live (inferred).

## Recommendation

Cheapest structure that keeps the developer outside the likely liability (inferred, needs lawyer sign-off):

1. **Contracts:** immutable, no owner, no pause, no upgrade proxy, no fee address controlled by the developer. Fees, if any, go to the foreign operator or are burned. Publish source and verify on Basescan. Cost: gas only.
2. **Frontend operator:** a Panama foundation (about $2-5k setup, about $1.5-5k a year, about one week) or an existing independent operator. The developer holds no shares, board seat, treasury key, hosting account, domain or fee entitlement. Geoblock Vietnam, the US, sanctioned regions and others the lawyer names.
3. **Developer's own deliverable in Vietnam:** points/testnet product only (the safe side in the prior note). Real money is another party's product.
4. Without relocation, personal risk is reduced, not eliminated. If the developer is a Vietnamese citizen, Art. 6 can reach acts abroad.

Estimated total: about $2-5k plus legal review (lawyer fees are my estimate, a few thousand dollars, inferred). Time: 2-4 weeks including review.

Cheaper alternative: ship points only and let a third party fork the open-source contracts. Cost $0, lowest risk (inferred).

## Questions a lawyer must confirm

1. Does a USDC-staked prediction market on Base meet the Art. 321/322 definition of gambling, and is a developer who wrote and deployed the contracts but runs no frontend and takes no fees treated as an accomplice?
2. Citizenship and residence: does Art. 6 apply, and does living in Vietnam while contributing code to a foreign entity create liability?
3. Can the developer hold any role (shareholder, director, contractor) in the offshore operator, or is a clean separation required? What separation test would prosecutors apply?
4. Does a Vietnamese user's use of the product, via local banks or exchanges, create liability for the developer, and do Resolution 05/2025 and Decree 327/2026 change this?
5. Panama versus BVI versus Cayman: gambling rules (I did not find Panama's gambling law), banking access, nominee reliability.
6. US exposure: with a US/Canada geoblock and no US users, are there residual CFTC, DOJ or state risks for a non-US developer?
7. Do market creators and liquidity seeders face liability, and what terms and geoblocks reduce it?
8. Tax and sanctions screening for the foreign entity and fees.

## Gaps

Opinion and Melee terms and entities not confirmed. Panama gambling law not checked. Vietnamese statutes not read in the official gazette. No Vietnamese case on pure code authors found; searches were shallow and mostly English. All cost numbers are vendor estimates.
