# Where futarchy and niche decision markets have a payer

Label: wayfinder:research
Type: research
Status: resolved

## Question

This is candidate D: futarchy, or decision markets (conditional "if we do X, what happens to metric M" markets), applied to a niche. The human named two example niches. Treat them as examples, not the full list.

- **AI compute marketplace.** Cover both readings: (1) markets on compute itself (GPU-hour price or availability futures, forward curves, hedging), and (2) futarchy or decision markets that govern a compute marketplace's choices (pricing, provider admission, emissions), for example in decentralized compute networks. Name what exists (exchanges, futures, DePIN networks), its volume, and who pays: hedgers, buyers, providers, or a treasury.
- **Opinion or attention markets on posts and writing, for example on X/Twitter.** Cover the readings: markets on whether a post or writer gains reach or is judged right later, creator or content coins, mindshare or attention markets, and markets on public opinion of a take. Name what exists, its usage, and who pays. Note known failure modes: manipulation, bots, wash trading, beauty-contest drift.
- **Futarchy in general.** MetaDAO, Futarchy Labs on Seer/GnosisDAO, Butter, and any 2025–2026 entrants. Who pays for conditional-market liquidity, and has any adopter paid twice? Build on, don't repeat, `docs/research/free-seeding.md` (branch `research/free-seeding`) and `docs/research/conviction-markets.md` (branch `research/conviction-markets`).
- Any other niche where research shows a decision-market payer.

Apply the map's kill rule to each niche: (i) a payer who paid for something similar in the last 12 months, and (ii) whether an incumbent already gives it away free. Rank up to 5 niches. Do not pick one; [Which candidates survive the kill rule](04-which-candidates-survive-the-kill-rule.md) does.

## Answer

Ranked niches with kill-rule results (no niche passes both rules for a new entrant):

1. **Ownership-coin futarchy (MetaDAO and its launchpad).** Rule (i) passes: projects and traders paid MetaDAO real money (Q4 2025 fees $2.51M, falling to $376.5K in Q2 2026, secondary). Rule (ii) kills it for an entrant: decision markets and their liquidity (about 50% borrowed from the project's own spot pool) are bundled into the raise.
2. **Compute price futures and hedging (CME, ICE, Kalshi, Ornn).** Money is real (Ornn raised $33M; Jump and DRW plan to make markets) but this is derivatives, not decision markets, and regulated incumbents own it. No volume found. Futarchy governing a compute network: no example, fails (i).
3. **Grant-allocation conditional markets (Butter, Uniswap Foundation, Optimism, Gnosis).** Fails (i) (last vendor payment Oct 2024) and (ii) (liquidity platform-seeded or returnable). Same as candidate A.
4. **Attention and opinion markets (Polymarket x Kaito; creator coins).** About $5.4M cumulative volume by June 2026; no outside liquidity payer found; Polymarket and Kaito hold it. Bots are a documented problem. Zora creator-coin volume fell 99.8% from peak. Fails (i) and (ii).
5. **Corporate decision markets.** Cultivate Labs reportedly dropped markets; no named payer. Fails (i).

- Nobody pays a third-party vendor for conditional-market liquidity; platforms or the DAO's own pool supply it.
- The only repeat payment found is MetaDAO projects paying through raises and trading fees, which is capital formation, not a forecast fee.
- No other niche with a decision-market payer turned up.

Caveats: most numbers are secondary (news and analytics blogs); MetaDAO raise totals conflict by an order of magnitude; CME and Kalshi press releases could not be fetched and CME's Oct 5 launch is unconfirmed; GIP-145 and CFM 2 results are not out.

Findings: docs/research/futarchy-niches.md on branch research/futarchy-niches, commit 8da1341. Branch is local; no origin remote.
