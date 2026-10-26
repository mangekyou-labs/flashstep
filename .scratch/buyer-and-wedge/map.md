# Which buyer and wedge to build for

Label: wayfinder:map

> **Done 2026-10-20.** Decided in [One buyer and one wedge](issues/06-one-buyer-and-one-wedge.md). The demand gate described there then failed on 2026-10-20 with "no buyer" (recorded in [Whether forecast buyers answer the demand test](../budgeted-forecast/issues/14-whether-forecast-buyers-answer-the-demand-test.md)). The venture track stops.

## Destination

A decision record naming **one buyer** (who pays for liquidity and resolution, and why they would pay again) and **one wedge**, backed by public evidence and direct buyer signals, and saying which spec gets written next: the paused [Budgeted forecast for one protocol community](../budgeted-forecast/map.md) or a new one. The map ends at the decision. Writing that spec is the next effort.

## Notes

- Goal is a venture: real users and a sponsor paying real money. Demand evidence is the gate for everything.
- Candidates:
  - **A.** Budgeted forecast for funded decisions (the paused map).
  - **B.** Conviction market. Leading meaning: time-locked stakes, where holding longer counts as stronger conviction. Research covers all variants.
  - **C.** Specialized long-tail market where Polymarket and Kalshi are thin. C survives only if it names a niche *and* who pays for its liquidity. Otherwise it collapses into A or B.
  - **D.** Futarchy or decision markets in a niche. Examples raised: an AI compute marketplace, and opinion or attention markets on writing and posts (X/Twitter). Same survival test as C.
  - **E.** Trader-paid niches: betting formats and verticals people already pay for in traditional gambling but that are missing or thin onchain (F1 and motorsport, parlays, props, in-play, pari-mutuel, casino-adjacent), plus AI-agent trading arenas. Here bettors are the payer, not a sponsor. Same survival test as C.
  - **F.** Forecast buyers: funders who already pay for forecasts (Metaculus, Good Judgment, prize pools) buy a forecast on their question, produced by a market. Added by [Which candidates survive the kill rule](issues/04-which-candidates-survive-the-kill-rule.md).
- A standalone oracle product is not a candidate. An optimistic or dispute oracle is a possible upgrade to whichever candidate wins, especially for fuzzy, judgment-based questions. For those questions this reopens the old map's rule that the oracle is "a stated weakness, not a wedge".
- Compare candidates on one axis first: who pays for liquidity and resolution, and why they pay again. Mechanism comes second.
- **Kill rule.** Drop a candidate if (i) no payer can be named who paid for something similar in the last 12 months, or (ii) an incumbent already gives that payer the same thing free (as Seer seeded the Zcash grant markets itself). Reading: (i) is a hard cutoff, and paid forecast prize pools count as "something similar". (ii) applies whenever an incumbent lists the market, however thin. (iii) A known legal block that would stop any entrant also kills.
- Talking to buyers is in scope as HITL task tickets: about 5 potential payers per surviving candidate, and at most two candidates go to outreach.
- No existing community, protocol, or niche access. Candidate C's niche and the outreach targets are chosen from research alone.
- Time box: started 2026-10-20; force the decision by **2026-11-03** even if evidence is incomplete.
- Mechanisms already rejected on the paused map stay rejected as *claims* unless a ticket here reopens them with evidence: LP rewards from token emissions, AMM versus order book, the token lock, the pricing mechanism on its own.
- Skills every session should consult: grilling, domain-modeling, research.
- Research tickets run on Sonnet at medium effort.
- Plan, don't do. Don't build or rewrite contracts or UI while this map is open.

## Decisions so far

- [Whether free seeding undercuts a paid forecast](issues/01-whether-free-seeding-undercuts-a-paid-forecast.md): platforms give liquidity away (Seer fully funded the Zcash pilot at about 20k sUSDS; Futarchy Labs charges no fee and GnosisDAO's $100k is returned). No outside party paid a non-returned forecast fee in the last 12 months; the last foundation-to-vendor payment was UF's $200k Butter grant, Oct 2024. Candidate A hits kill rule (ii) on liquidity. A paid A would have to sell the cost ceiling, stated depth, the resolver, or insider resistance, and no evidence shows anyone pays for those.
- [Where futarchy and niche decision markets have a payer](issues/07-where-futarchy-and-niche-decision-markets-have-a-payer.md): no niche passes both kill-rule tests for an entrant. Only MetaDAO ownership-coin futarchy has a payer (fees falling from $2.51M in Q4 2025 to $376.5K in Q2 2026, secondary source), with liquidity bundled into the raise (fails rule ii). Compute futures are regulated derivatives, and no futarchy governs a compute network. Grant markets fail like A. Attention markets (Polymarket x Kaito, Zora down 99.8%) fail both rules. Corporate decision markets have no named payer. Nobody pays a third-party vendor for conditional-market liquidity.
- [Which long-tail niches have a payer](issues/03-which-long-tail-niches-have-a-payer.md): no niche passes kill rule (i) cleanly. The closest payers buy *forecasters*, not markets: Coefficient Giving commissioned Metaculus Pro Forecasters on research-funding outcomes (Sep 2025) and funds FRI on AI questions, but those payments are 13+ months old. Metaculus's AI benchmark ($58K prize) and Bridgewater x Metaculus ($30K) are in-window prize pools. Polymarket/Kalshi AI sub-markets are thin ($3–7K liquidity). Corporate forecasting runs about $20K/yr (Good Judgment), and Cultivate Labs left markets. Hedging is served by Kalshi. Protocol-metric markets have no payer.
- [Which traditional betting formats are missing onchain](issues/08-which-traditional-betting-formats-are-missing-onchain.md): two gaps pass with bettors as payer, both thin or legally gated. Pari-mutuel horse racing ($11.04B US handle in 2025, no onchain incumbent) is blocked by the Interstate Horseracing Act (Polymarket pulled its Derby market). F1 per-race and in-race is a weak pass: Polymarket F1 volume is almost all season titles, about $234K for a single race winner. In-play, casino-style binaries, parlays (Kalshi Combos 67.2% of weekly volume; Polymarket US parlays; Overtime), props, and esports already have incumbents.
- [Whether AI-agent trading arenas have a payer](issues/09-whether-ai-agent-trading-arenas-have-a-payer.md): no variant survives. Polymarket already runs AI-outcome markets at depth (Alpha Arena S1 about $1.0M; monthly top-model markets $0.9–4M), but S1.5 fell to $58K. Labs pay for evaluation (LMArena about $30M annualized), not markets, and they are the ranker's customers. Sponsor money (Nof1 $15M raise, prize pools) is equity or tokens behind free arenas. Agents are participants, not payers (30%+ of Polymarket wallets). Caveat: about 25% of Polymarket volume may be wash trading.
- [Who already runs conviction markets](issues/02-who-already-runs-conviction-markets.md): there is a gap but no payer. No live product weights forecasts by lock time; the nearest are governance mechanisms (ve-tokens, Bittensor locks, 1Hive Gardens). Candidate B fails kill rule (i) on current evidence. Polymarket's free 4% holding reward touches rule (ii).
- [Which candidates survive the kill rule](issues/04-which-candidates-survive-the-kill-rule.md): only the new candidate F survives: forecast buyers in AI capability and release timing, with C folded in. A, B, D and E are killed (F1 per-race fails (ii) on Polymarket; horse racing fails the new legal-block part). F goes to outreach alone with five targets: Coefficient Giving, FRI, Anthropic, OpenAI, and Metaculus as a channel.
- [What payers say when asked](issues/05-what-payers-say-when-asked.md): outreach skipped, nothing sent, so zero direct buyer signals (not the same as "no"). Candidate F rests on public evidence only. Contacts and drafts are ready if revived. A new in-window payer was found: Renaissance Philanthropy and the Schultz Family Foundation funded the Metaculus Labor Automation Hub (Apr 2026).
- [One buyer and one wedge](issues/06-one-buyer-and-one-wedge.md): provisional pick is candidate F. The buyer is forecast buyers, led by Coefficient Giving (it keeps re-asking AI-timing questions for its grants). The wedge is AI capability and release-timing questions. No spec next. The next effort is a demand gate: six targets, two weeks, pass on any "pay", "maybe", or a Metaculus channel talk; otherwise "no buyer" and stop. Budgeted-forecast map abandoned; Greenlight code untouched.

## Not yet specified

None. The map is complete.

## Out of scope

- A standalone optimistic-oracle product (the oracle is only an upgrade).
- Writing the next handoff spec.
- Building, deploying, or deleting any code.
- Competing with Polymarket or Kalshi on mainstream events.
- Demand tests and licensing for bettor-paid formats: no bettor-paid candidate survived [Which candidates survive the kill rule](issues/04-which-candidates-survive-the-kill-rule.md).
- Which oracle or dispute upgrade F's capability questions need, and what to do with the Greenlight bonding-curve code. Both belong to F's spec, which comes after this map's decision. See [One buyer and one wedge](issues/06-one-buyer-and-one-wedge.md).
