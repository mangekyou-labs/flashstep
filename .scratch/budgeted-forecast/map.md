# Budgeted forecast for a forecast buyer

Label: wayfinder:map

> **Stopped 2026-10-20: no buyer.** It was redirected earlier the same day to candidate F (forecast buyers asking AI capability and release-timing questions; see [One buyer and one wedge](../buyer-and-wedge/issues/06-one-buyer-and-one-wedge.md)). Then [Whether forecast buyers answer the demand test](issues/14-whether-forecast-buyers-answer-the-demand-test.md) failed. The venture track stops, and [the spec](spec.md) is shelved as prior art. Do not resume this map unless a forecast buyer turns up; that would be a fresh effort.

## Destination

A handoff spec, ready for an agent, for one budgeted forecast that a forecast buyer publishes on its own AI capability or release-timing question. The spec states:

- the maximum subsidy and the separate resolution cost;
- the Depth that budget buys;
- the oracle those questions need;
- the forecast page readers see.

The draft exists. It becomes the destination once the demand test passes and the oracle question is settled. If the test fails, the map stops with "no buyer". The bonding-curve market and the Greenlight UI stay in the repo, unchanged, for inspection.

## Notes

Standing preferences from the frontier. These are not closed tickets.

- Question template: four pins (data source, observation window, deadline, invalid-result rule) plus a required influence line (see Decisions so far). One live forecast; a series is several forecasts. Example of a filled template, not the frozen question: "Will a model score at least X on benchmark B (version V) by date D?" The data source names the exact leaderboard and version, or the lab's official channel and what counts as a release. The buyer's real first question comes from the demand test.
- Cost function: prior-based LMSR. The forecast buyer sets the opening probability as a parameter of that cost function. No opening lock and no lock percentage.
- Subsidy: maximum subsidy in ETH is a hard ceiling on the forecast buyer’s trading loss. Resolution cost is a second ETH amount, stated beside the subsidy, and paying it does not shrink the trading ceiling. A dollar figure may appear as a label. The amount that can actually be drawn is the ETH amount. The forecast buyer is not owed a return on either amount.
- Trading fee: traders pay the LMSR cost only. No trading fee.
- Resolver: a resolver publishes the outcome by applying the template’s rule to the named source. The template’s invalid result is its own outcome. It is not stored as Yes or No.
- Who trades: anyone with a wallet can trade. The forecast buyer is the reader the forecast is for. Trading is not limited to the forecast buyer’s team.
- Forecast readout: current probability, executable quote for a size, and the probability after that size. Depth is that same size-versus-move relationship, computed from the subsidy and the opening probability. Participation is the total amount traded so far. Do not treat a wallet count as participation. Depth is stated as the ETH it costs to move the probability 5 points each way at the open (see Decisions so far).
- Surface: a Seer-style forecast page served by this repo and linked from the forecast buyer's own question page or report (see [How the forecast panel feels as one product](issues/11-how-the-forecast-panel-feels-as-one-product.md)). The current Greenlight pages stay in the repo unchanged, for inspection.
- `GLOSSARY.md` stays the language of the kept Greenlight UI. This map does not rewrite it. A new term is written down only when a decision in this effort settles it.

Skills every session should consult: grilling, domain-modeling, research, prototype.

Technical tickets (contract mechanics, payouts, resolution, quoting): apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.

Demand: the protocol-community evidence in [Whether protocol communities pay for forecasts](issues/08-whether-protocol-communities-pay-for-forecasts.md) is superseded. The evidence for F is weak: the only in-window payment is the $58K FutureEval prize pool, and Coefficient Giving's FRI grants are more than 13 months old. [Whether forecast buyers answer the demand test](issues/14-whether-forecast-buyers-answer-the-demand-test.md) gates every other open ticket. The CFTC interim final rule (2026-10-09) fits information-only questions less well; who may trade, and from where, is unsettled.

Do not reopen these discarded competitive claims: anyone can create markets; AMM versus order book; LP rewards; automatic objective resolution. They are already competitive elsewhere. Also discarded: the pricing mechanism as a claim (LMSR is how the price tag is delivered, not the claim) and the oracle (one named resolver is weaker than Seer's and TRUEO's; it is a stated weakness, not a wedge). Whether that weakness is acceptable for fuzzy AI questions is reopened in [Which oracle AI capability and release questions need](issues/16-which-oracle-ai-capability-and-release-questions-need.md); the oracle is still not a claim. See [What this forecast competes on](issues/13-what-this-forecast-competes-on.md).

Plan, don’t do. Do not delete or rewrite the bonding-curve contracts, tests, or Greenlight UI while this map is open.

The demand test, not a pilot interview, is the gate in front of building.

## Decisions so far

- [Prior-based LMSR subsidy bound](issues/01-prior-based-lmsr-subsidy-bound.md): hard sponsor loss scales with the liquidity parameter and the smallest opening probability; invert by dividing the subsidy ceiling by the log of one over that smallest probability; same rule for two and three outcomes; entropy is the expected loss, not this ceiling.
- [Whether protocol communities pay for forecasts](issues/08-whether-protocol-communities-pay-for-forecasts.md): mixed; foundations fund forecasts tied to grants they already allocate (Uniswap, Optimism), no evidence of a non-returned subsidy for an operational question; capped-subsidy shape itself is supported (Polymarket sponsor rewards). Destination redrawn toward decisions the sponsor already funds. **Superseded 2026-10-20** by the pick of candidate F.
- [Whether invalid is tradable](issues/02-whether-invalid-is-tradable.md): no; Invalid is a published status with no shares, the market is two-outcome LMSR bounded by min(p, 1−p); Invalid is distinct from Unpublished (no result by the deadline).
- [What traders and the sponsor are paid at resolution](issues/03-what-traders-and-the-sponsor-are-paid-at-resolution.md): winning shares pay a fixed Payout; Invalid pays half the Payout per share; only held shares are paid; the forecast buyer gets the Remainder at publication and keeps any gain; claims never expire.
- [Who is paid the resolution cost](issues/04-who-is-paid-the-resolution-cost.md): one fixed resolver named at publish, barred from being the forecast buyer's address (disclosed trust assumption); resolution cost escrowed, paid to the resolver on any publication; trading closes at window end, Invalid publishable early, results final; after the deadline anyone settles Unpublished, which pays like Invalid and returns the resolution cost to the forecast buyer. **Amended 2026-10-20:** the single-resolver choice is reopened in [Which oracle AI capability and release questions need](issues/16-which-oracle-ai-capability-and-release-questions-need.md).
- [Which probability move states the depth](issues/05-which-probability-move-states-the-depth.md): the ETH it costs at the open to move the probability 5 points, stated up and down; a fixed fraction of the subsidy (15.2% each way at 50%); computed once at publish.
- [How the open forecast panel reads](issues/06-how-the-open-forecast-panel-reads.md): headline probability, a row of traded / subsidy / resolution cost, the fixed depth-at-open line, and a one-sentence buy quote for a size the reader enters (shares and probability after); a size ladder sits in a collapsed fold-out; buy only (sell quotes live with holdings); no live depth figure; resolver named in the footer.
- [Whether subsidy and opening probability can change after publish](issues/07-whether-subsidy-and-opening-probability-can-change-after-publish.md): everything set at publish is fixed; no top-ups from anyone (co-sponsors pool before publish, one sponsor address); subsidy locked until publication or Unpublished settlement; sponsor may withdraw only before the first trade (Withdrawn, both amounts returned); opening probability in whole points from 10% to 90%.
- [What the forecast says when a trader can move the outcome](issues/09-what-the-forecast-says-when-a-trader-can-move-the-outcome.md): nothing enforced onchain (disclosed trust assumption); a required influence line set at publish names the interested parties and whether grant terms bar them from trading, always shown on the panel; spec recommends a two-way trading ban in the grant agreement; a breach leaves the result standing; guidance (no ratio) to keep the subsidy small next to the grantee's stake. **Amended 2026-10-20:** the influence line names labs; no grant clause; the subsidy is sized as the price of the forecast, with insiders assumed to take most of it.
- [How the panel reads after trading closes](issues/10-how-the-panel-reads-after-trading-closes.md): same card, headline and quote swapped by state; result word (or frozen probability while awaiting / Unpublished) with the closing forecast beside it; resolution cost row shows where it went; status line plus payout-per-share line replace the quote; claim action wherever shares pay; Remainder kept off the panel.
- [How the forecast panel feels as one product](issues/11-how-the-forecast-panel-feels-as-one-product.md): amended 2026-10-19 to a Seer-style forecast page: question, meta line and chance chart first; outcome rows with large %; a sticky trade box (Buy/Sell tabs, receipt rows) or result box with holdings and claim; key dates, plain-language rules and "who pays" below; Depth and the "More sizes" ladder leave the reader view. Motion rules and connect / pending / error / chain-down states stand.
- [How Seer and TRUEO serve a funded decision](issues/12-how-seer-and-trueo-serve-a-funded-decision.md): no sign either offers a bounded sponsor subsidy, depth stated at publish, or influence disclosure; both use pool AMMs with LP incentives and stronger oracles (Seer: Reality.eth + Kleros; TRUEO: bonded optimistic + council); Seer already has real grant use (Zcash grants poll, Deep Funding, GnosisDAO futarchy via Futarchy Labs); TRUEO's Cancelled pays half like this map's Invalid. **Amended 2026-10-20:** panel incumbents moved to [How Metaculus and FRI serve a forecast buyer](issues/17-how-metaculus-and-fri-serve-a-forecast-buyer.md).
- [What this forecast competes on](issues/13-what-this-forecast-competes-on.md): a forecast with a price tag; the forecast buyer knows the worst-case cost (subsidy ceiling + resolution cost) and the depth it buys (ETH to move 5 points) before publish; LMSR, panel and influence line support it; oracle stated openly as weaker than Seer/TRUEO; spec opens with a one-sentence positioning line filled from publish values. **Amended 2026-10-20:** the wedge carries over to forecast buyers, against panels and thin public AI markets; the oracle ruling is reopened for fuzzy questions.
- [Whether forecast buyers answer the demand test](issues/14-whether-forecast-buyers-answer-the-demand-test.md): fail, no buyer; venture track stops and the spec is shelved.

## Not yet specified

None. The map stopped at the demand test.

## Out of scope

- Building or deploying the forecast.
- Removing or rewriting the bonding-curve contracts, tests, or Greenlight UI.
- A marketplace or a general betting exchange.
- A claim of better accuracy.
- Choosing the forecast buyer's first real question (it comes from the demand test replies).
- The venture track after a failed demand test.
- AI economic-impact questions as a first target (the runner-up wedge).
- Rewriting the Greenlight glossary.
- A forecast comparing several candidates in one market. A round with several candidates is several separate binary forecasts, each with its own subsidy.
- A buyer layer on top of Seer (seeding Seer pools and reporting a ceiling), Polymarket, or Kalshi. Seer would bring along its full-paying Invalid token, Reality.eth timing, and range-dependent pool depth, all of which this map rejected; the public venues don't let the buyer set the question or the depth. See [What this forecast competes on](issues/13-what-this-forecast-competes-on.md).
- The oracle for fuzzy AI questions, how other venues resolve them, and how the panel incumbents compare: closed when the demand test failed. See [Which oracle AI capability and release questions need](issues/16-which-oracle-ai-capability-and-release-questions-need.md), [How AI capability and release questions are resolved elsewhere](issues/15-how-ai-capability-and-release-questions-are-resolved-elsewhere.md), and [How Metaculus and FRI serve a forecast buyer](issues/17-how-metaculus-and-fri-serve-a-forecast-buyer.md).
- The fog left open when the map stopped: hosting, currency, the Remainder view, what happens to the Greenlight code, and who may trade under the CFTC rule. None of it gets decided now that there is no buyer.
