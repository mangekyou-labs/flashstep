# How crypto operators buy game content

Research for ticket 27. Not legal advice. Date: 2026-10-26.

Labels: **sourced** = stated on a first-party page I fetched (the page's own text, relayed through a fetch tool); **sourced (secondary)** = licensing-agency, aggregator-blog, news or directory report; **inferred** = my reasoning.

## Summary

- The standard deal is revenue share on the operator's gross gaming revenue (GGR), paid by the operator to the provider, with the aggregator taking a slice. Slotegrator says operators pay no minimum monthly fee for content, "only the revenue share" (sourced). Hub88 says suppliers may use revenue share, fixed fees or hybrid models, and publishes no percentages (sourced). Typical numbers are only secondary: 10-15% of GGR for premium content (sourced, secondary, one commentary piece); an illustrative 14% content fee with 4% to the aggregator, 10% to the studio (sourced, secondary, explicitly an assumption).
- Aggregators gate on licence plus certification, not on code. Hub88 vets suppliers on regulatory licensing, game quality, technical reliability, existing player engagement and commercial terms; it prefers multi-jurisdiction licences and relies on eCOGRA, GLI, iTech Labs and BMM certificates (sourced). Slotegrator says it works "only with certified game developers" (sourced). SoftSwiss publishes no studio-application page, only a contact address (sourced). A solo dev with no supplier licence and no lab certificate does not clear this gate (inferred).
- Supplier licences cost real money. Curaçao B2B: EUR 4,592 application plus EUR 24,490 a year, a Curaçao company with local management, certified RNG, 2-6 months (sourced, secondary). Malta B2B: EUR 5,000 application, EUR 25,000-35,000 a year (sourced, secondary). Anjouan B2B: EUR 17,828 issue and renewal, or a recognition certificate around EUR 9,500 a year for suppliers already licensed elsewhere (sourced, secondary; sources disagree). All are far outside a $0 budget (inferred).
- **The one door that fits a $0 solo dev is Stake Engine ("Engine").** Anyone can sign in with Google, GitHub or Discord, upload static files, and get reviewed; the developer takes 10% of GGR, or a guaranteed 7.5% of expected GGR; no supplier licence is asked on the front page (sourced: stakeengine.org). Reported: over 1,000 publishers and 4,000 games in a year, USD 90m+ paid out (sourced, secondary). Catches: it is Stake only, the licence keeps developers exclusive to Stake's Curaçao operator, and Stake controls distribution (sourced, secondary: FairGambling). Whether crash or round-style games are accepted, and who owns the IP, I could not verify.
- Crash games are a crowded, concentrated category: roughly 90% of play goes to Spribe's Aviator, with SmartSoft, BGaming, Turbo Games and Hacksaw dividing the rest (sourced, secondary). Turbo Games, a small Estonian studio, sells a 50-title crash/mines/instant portfolio through one API with MGA, ONJN and GCGRA B2B licences (sourced: its own page). So small studios do sell crash games, but with licences and certificates the dev would not have (inferred).
- Prediction platforms: I found no evidence that Polymarket, Limitless, Myriad or Opinion buy or license market formats from outsiders. What exists is API and builder access: Polymarket's Builder Program (attribution codes, relayer tiers; sourced, secondary) and Limitless's REST/WebSocket API (sourced). The flow runs from platform to builder, not payment to the builder (inferred).
- Net for the map: the "vendor to operators" path works via aggregators only after a licence and a lab certificate; the cheap path is Stake Engine as a revenue-share creator, which is an Engine submission, not a pilot with an operator. A direct pilot with one small operator bypasses the aggregator, but I found no documented example (unverified).

## 1. The usual deal

| Claim | Detail | Label |
|---|---|---|
| Revenue share is a royalty on casino revenue from the software, set by each provider | Slotegrator FAQ: "Revenue share is essentially a royalty fee", a percentage of the casino's revenues from the software; "Each provider has specific revenue share terms"; details come in a commercial offer from managers (https://slotegrator.pro/faq.html) | sourced |
| No minimum monthly payment for content | Slotegrator: "We do NOT charge minimum monthly payments for game content"; the client pays only the revenue share | sourced |
| Platform pricing is separate and quoted per project | Slotegrator FAQ: platform cost depends on technical requirements; no setup fee listed for content | sourced |
| Hub88 commercial models | Revenue share, fixed fees, hybrid; consolidated into one framework; no published percentages; custom terms negotiable for high-value suppliers (https://hub88.io/casino-game-suppliers/) | sourced |
| Percentage range | 10-15% of GGR for premium casino content, higher for hits; "none of the figures are audited" (Medium commentary on Spribe) | sourced (secondary) |
| Split example | 14% content fee, 4% to aggregator, 10% to studio, labelled as an assumption (Idea Usher; page returned 403 to me, so this came via a search summary) | sourced (secondary), weak |
| A directory lists Slotegrator revenue share "from 15%", range 15-25%; a later review withdrew ranges as indefensible | Treat as unreliable | sourced (secondary), low trust |
| Flat licence or setup fee for a content provider | Slotegrator and Hub88 describe none for content; a review says a setup fee and ongoing commission exist but are undisclosed | sourced / sourced (secondary) |
| A new provider's share is likely well below 10% of GGR once an aggregator sits between | Arithmetic from the illustrative split above | inferred |

Engine's published terms (the clearest real numbers): developer picks "10% GGR" profit share or "7.5%" guaranteed of expected GGR, paid on the 1st of each month for any sum above $0 (https://stakeengine.org/). The Easygo/Stake docs reportedly note negative-GGR months are normal and teams can sit on large losses before recovering (sourced, secondary).

For a 30-second Round game, the relevant point is that GGR-based pay depends on the operator's house edge. If a Round is a pooled or peer-against-peer market with no house-banked edge, there may be no GGR to share (inferred). This ties to the map's rule about no cut of stakes.

## 2. Aggregators versus direct integration

- **Hub88.** Onboards suppliers on regulatory compliance, quality, reliability, engagement and commercial terms; each candidate goes through integration testing, security audits and game certification checks; contact via sales@hub88.io or a contact form (sourced: https://hub88.io/casino-game-suppliers/). Technical bar (sourced: docs.hub88.io Supplier API Overview): the supplier hosts a `/game/url` endpoint, calls Hub88's wallet endpoints `/user/balance`, `/transaction/bet`, `/transaction/win` and `/transaction/rollback`, signs requests with RSA-SHA256 (`X-Hub88-Signature`), and handles idempotent `request_uuid`. Docs list a Supplier Games SDK (April 2026 changelog). The docs index shows no page on certification or go-live (sourced).
- **SoftSwiss Game Aggregator.** Describes itself as an authorised reseller for "dozens of game vendors and game development studios"; the providers page has no application path, only "Let's talk" and an email (sourced: https://www.softswiss.com/game-providers/). About 50,000 games from 300+ providers and a roughly 3-week operator integration (sourced, secondary). Studio terms and wallet spec: not public.
- **Slotegrator.** "New game providers monthly", only certified developers, lab-tested; no provider application process on the FAQ (sourced).
- **Direct integration.** The operator signs the provider directly, typically for bigger names. No source I found describes a small studio doing this; Stake's route is the nearest case (inferred).
- **What an aggregator requires, in short:** a licence, a lab certificate, a wallet/launch API, and a commercial case (sourced / inferred). The technical part (a few signed REST calls) is doable by one dev; the licence and certificate are the barrier (inferred).

## 3. Supplier licences, certification and cost

Fee figures are from licensing agencies and law-firm sites, not regulators' own pages (CGA's front page gave no fee schedule when I fetched it; MGA's pages were not reachable through my search). Re-check against the regulator before relying on them.

| Jurisdiction | Application | Annual | Time / conditions | Label |
|---|---|---|---|---|
| Curaçao (CGA, LOK) | EUR 4,592 | EUR 24,490 supervisory; no National Treasury fee on B2B; EUR 150 per UBO | 2-6 months; Curaçao company, local management or resident director, key person, compliance function; certified RNG/games; hosting in Curaçao or approved jurisdiction | sourced (secondary) |
| Malta (MGA) B2B Type 1 | EUR 5,000 | EUR 25,000 (up to EUR 5m revenue), 30,000, 35,000 | Capital EUR 40,000 per one source, EUR 100,000 per another | sourced (secondary), conflicting |
| Anjouan | n/a | EUR 17,828 issue and renewal; recognition certificate about EUR 9,500 a year for already-licensed suppliers | 4-8 weeks; Costa Rica applicant company reported; direct B2B licence or certificate required from July 2025 | sourced (secondary), conflicting (one site lists other figures) |

- Certification: test labs named by Hub88 are eCOGRA, GLI, iTech Labs and BMM Testlabs (sourced). Per-game certificates cost money; I found no price (unverified).
- Cost of the cheapest cash path: tens of thousands of euros a year plus lab fees, against a $0 budget (inferred).
- Spribe's UKGC licence was suspended 30 Oct 2025 and reinstated 30 Mar 2026 over hosting games without a separate hosting licence (sourced, secondary), a sign regulators scrutinise suppliers.
- Provably fair is not a licence substitute: Hub88 asks for certified RNGs and "regular fairness audits" (sourced). Whether a fully onchain, verifiable settlement is accepted in lieu of an RNG certificate: unverified.

## 4. Crash games and in-house "originals"

- Crash is sold as ready-made titles through aggregators (Spribe, SmartSoft, Pragmatic, Evolution via SoftSwiss, EveryMatrix, BetConstruct, Slotegrator) with launch in days (sourced, secondary).
- The crash mechanic is described as easy to copy and not protectable; the IP of Aviator is disputed (sourced, secondary), which suggests operators pay for certification, brand and reach, not the idea (inferred).
- Game-Ace says the hard parts are provably fair design, real-time state, anti-cheat, operator integration and certification, not the core mechanic (sourced, secondary).
- **Turbo Games** (Estonia): own site lists MGA, ONJN, GCGRA B2B licences, per-game BMM certificates, under-one-week integration, a 50-title crash/mines/vortex/instant catalogue; custom or original work is not mentioned (sourced: https://turbogames.io/for-business/). A third-party profile claims a Curaçao-only licence and Yolo Group ownership; this conflicts (sourced, secondary).
- **Stake originals.** Engine was reportedly first used for Stake's in-house content before opening to outsiders (sourced, secondary). Whether other operators' originals are built in-house or contracted: unverified.
- Small studios do sell: Engine reportedly hosts 1,000+ publishers (sourced, secondary). A 30-second Round title would be a "instant/crash-like" format, but its fit inside Stake's approved game types is unverified.

## 5. What a pilot looks like and who decides

I found no first-party description of a pilot process. What I did find:

- Hub88 operator onboarding is sales email, invitation to HubConnect, business information then technical integration, then compliance checks, testing, go-live (sourced via search summary of docs.hub88.io; operator side only).
- Telegram casinos (BC.Game, Betpanda and others) run exclusive games and bonus drops in their bot channels, and mostly resell the same big providers through aggregators such as SoftSwiss (sourced, secondary). That suggests exclusive in-bot content is operator-built (inferred).
- Who decides at an operator (game or content manager, product, partnerships, risk or compliance) and typical pilot terms (exclusive window, soft launch to a subset of players, reduced share): **unverified**. No source found. Treat as outreach questions, not facts.

## 6. Prediction platforms

- **Polymarket.** Builder Program: apps route orders using builder codes; tiers Unverified (100 relayer tx a day), Verified (10,000), Partner (unlimited); upgrade by emailing builder@polymarket.com (sourced, secondary; the docs page was in the results but I did not fetch it).
- **Limitless.** Docs offer REST and WebSocket API; no partner, white-label or market-licensing programme found on the docs home (sourced: https://docs.limitless.exchange). Support contacts only.
- **Myriad, Opinion.** No programme found (unverified; not fetched).
- Third-party aggregators (pmxt, FinFeedAPI, PolyRouter, Predictefy) normalise data across these venues (sourced, secondary), meaning data feeds are being built by outsiders, not bought from the platforms.
- Finding: no evidence these platforms purchase external market formats or feeds. Opening that door would be a cold ask (inferred).

## Fit with the map

- Matches the map's default payer assumption partly: buying content is routine, but the path for a licence-less solo dev is Engine-style submission or a direct small-operator deal, not a mainstream aggregator (inferred).
- Revenue share on GGR implies a house-banked edge. The map's legal rule forbids the dev taking a cut of bettors' stakes; paid-by-operator GGR share keeps the dev a vendor, but whether it counts as a cut of stakes is a lawyer question (inferred).
- Outreach targets in priority: Engine (apply, read /docs/terms and /docs/approval-guidelines first), then small crypto operators for a direct pilot, then aggregator sales desks (Hub88, SoftSwiss, Slotegrator) only to ask the licence question (inferred).

## Unverified

- Engine's actual legal terms (/docs/terms), IP ownership, approval guidelines, permitted game types, certification, and whether Engine's exclusivity and IP clauses apply (fetches of studio.engine.io returned only logos; stakeengine.github.io/math-sdk returned 404).
- Whether Engine will take a Round/prediction-style game, and the Medium Rare N.V. detail (via FairGambling only).
- Any percentages for new providers at Hub88, SoftSwiss or Slotegrator.
- Hub88 certification and go-live steps for suppliers; SoftSwiss studio spec.
- Regulator-published fees for CGA, MGA and Anjouan; the Anjouan site anjouongamingboard.org conflicts with others and I could not tell which is official (anjouangamingboard.org did not resolve).
- Lab certification prices and timelines.
- Whether verifiable onchain settlement can replace an RNG certificate.
- How pilots are structured and who signs them at operators; Telegram-group purchasing.
- Any prediction platform buying or licensing formats; Myriad and Opinion programmes; Polymarket docs not fetched directly.
- Idea Usher page returned 403; Polymarket and Spribe items rest on search summaries, not fetched pages.
- Most licence and crash-market facts are secondary because regulator and provider pages gave little; many tool results were summaries of pages, so quotes should be rechecked on the source.
