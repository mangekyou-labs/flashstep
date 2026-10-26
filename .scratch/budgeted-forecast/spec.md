# Budgeted forecast for a forecast buyer

Status: **shelved 2026-10-20.** The demand test failed with "no buyer" (see [Whether forecast buyers answer the demand test](issues/14-whether-forecast-buyers-answer-the-demand-test.md)). Do not hand it off. It is kept as prior art.

> **"This forecast costs you at most X ETH plus Y ETH to resolve, and at open a trader must spend Z ETH to move it 5 points."**
>
> X is the maximum subsidy, Y the resolution cost, Z the Depth, all filled from the values set at publish. If this sentence can't be written for a forecast, the forecast isn't ready to publish. It is also the answer to "why not a forecaster panel" and "why not the thin Polymarket market".

Source: candidate F as picked in [One buyer and one wedge](../buyer-and-wedge/issues/06-one-buyer-and-one-wedge.md) on the map [Which buyer and wedge to build for](../buyer-and-wedge/map.md), plus the mechanics settled by the 13 resolved tickets of the map at `.scratch/budgeted-forecast/map.md`. This spec reworks the earlier "Budgeted forecast for one protocol community". The buyer and the question change. The market mechanics carry over.

Written 2026-10-20 at the human's request. This overrides the decision in One buyer and one wedge that no spec is written before the demand test passes. The test still gates building.

## Problem Statement

A **Forecast buyer** is a funder that already pays for forecasts on its own questions. Coefficient Giving is the lead example: its AI-governance and forecasting grants keep returning to AI capability and release-timing questions such as "Will a model score at least X on benchmark B by date D?" or "Will lab L release model M before date D?". Renaissance Philanthropy, through the Metaculus Labor Automation Hub, is a second payer of the same kind.

Today the buyer has two options, and neither gives a market forecast on its own question at a known cost:

- **Forecaster panels and commissions.** FRI's LEAP panel cost $1.07M. Metaculus Pro Forecasters were commissioned in September 2025, price unpublished. Both buy forecasters' judgement, not a price that traders back with money. The cost is negotiated per engagement and is not tied to any stated depth.
- **Public markets.** Polymarket and Kalshi list some AI questions, but they are thin: $3–7K of liquidity, with some monthly markets trading $13 in 24 hours. The buyer can't choose the question, its source, or its deadline, and can't fund the market to a known depth.

So the buyer can't answer two simple questions in advance: "What is the most this market forecast can cost us?" and "How hard is it for one trader to push the number around?" Without those answers, a market forecast can't be budgeted alongside the panels the buyer already pays for.

## Solution

A **budgeted forecast**: one binary question that the forecast buyer names, priced by a prior-based LMSR. The first questions it is built for are AI capability and release-timing questions. Before publishing, the buyer chooses four amounts and settings:

- a maximum subsidy in ETH, which is a hard ceiling on the buyer's trading loss;
- a separate resolution cost in ETH;
- an opening probability;
- a Payout per winning share.

From those numbers the forecast states, at publish, exactly what it can cost (the subsidy ceiling plus the resolution cost) and what that money buys: the Depth, meaning the ETH a trader must spend at the open to move the probability 5 points each way.

The question is written from a template with four pins (data source, observation window, deadline, invalid-result rule) plus a required influence line. For AI questions, the data source names the exact page and version that decides the result, such as a benchmark leaderboard with its version or a lab's official release channel. The influence line names the Interested parties: the labs whose staff can bring the result about or already know it, such as a release date. One named resolver publishes Yes, No, or Invalid, and it can never be the buyer's address. Anyone with a wallet can trade Yes and No. There is no trading fee.

A buyer that wants a series, for example one benchmark threshold per quarter, publishes several separate forecasts. Each has its own subsidy.

The forecast is read on its own forecast page, laid out like Seer's market page, which the buyer links to from its own question page or report. The page leads with the question, the current chance of Yes, and a chart of how it has moved. Beside it, a trade box lets a reader buy or sell Yes or No. Before the reader confirms, it shows the shares they get, the average price, what they win if they are right, and how far their trade moves the chance. Below sit the key dates, how the question resolves, and, in plain words, who pays for the forecast.

After trading closes, the trade box becomes a result box. It shows the result, the payout per share, the connected wallet's shares, and a claim action.

## User Stories

### Forecast buyer: publishing

1. As a forecast buyer, I want to set a maximum subsidy in ETH, so that I know the most my forecast can lose to traders before I publish.
2. As a forecast buyer, I want to set a resolution cost in ETH that sits beside the subsidy and doesn't reduce it, so that paying the resolver never thins the market.
3. As a forecast buyer, I want to set an opening probability in whole points from 10% to 90%, so that the market starts at my honest prior, or at a prior taken from a panel forecast I already bought.
4. As a forecast buyer whose honest prior is more extreme than 10% or 90%, I want to open at the limit and let traders move the price further, so that the Depth line stays meaningful.
5. As a forecast buyer, I want to set a fixed Payout per winning share, so that traders know from the start what a winning share is worth.
6. As a forecast buyer, I want to fill in the four pins (data source, observation window, deadline, invalid-result rule), so that the question can be resolved without argument.
7. As a forecast buyer asking a benchmark question, I want the data source to name the leaderboard, the benchmark version, and the score threshold, so that a renamed or re-versioned benchmark falls under the invalid-result rule instead of a judgement call.
8. As a forecast buyer asking a release-timing question, I want the data source to name the lab's official channel and to say what counts as a release (general availability, API access, or an announcement), so that a staged rollout doesn't leave the result in dispute.
9. As a forecast buyer, I want to name one resolver address (a person, a multisig, or a committee contract), so that readers know who decides the result.
10. As a forecast buyer, I want publishing to be refused if I name my own address as the resolver, so that I can't openly settle a market whose Remainder I keep.
11. As a forecast buyer, I want to write a required influence line that names the labs whose staff can bring the result about or already know it, so that readers can judge the insider risk.
12. As a forecast buyer, I want publishing to be refused when the influence line is blank, so that the disclosure is never skipped.
13. As a forecast buyer, I want to see the Depth (the ETH needed to move 5 points up and down at the open) before I publish, so that I know what my subsidy buys.
14. As a forecast buyer, I want the positioning sentence filled in from my values before I publish, so that I can state the forecast's cost and depth in one line in my own report or grant write-up.
15. As a forecast buyer with co-funders, I want us to pool our funds before publishing from one buyer address, so that there is a single funder and a single recipient of the Remainder.
16. As a forecast buyer, I want the subsidy and resolution cost escrowed in one publish transaction, so that the forecast is fully funded from its first moment.
17. As a forecast buyer who made a mistake at publish (such as a typo in the opening probability), I want to withdraw the forecast while nothing has been traded, so that I get the subsidy and resolution cost back.
18. As a forecast buyer, I want the forecast to read Withdrawn after I withdraw, so that nobody mistakes it for an Invalid result.
19. As a forecast buyer, I want to be unable to withdraw once anyone has traded, so that traders can rely on the prices they accepted.
20. As a forecast buyer, I want every value set at publish to be fixed afterwards, so that the loss ceiling and the Depth stay true for the forecast's whole life.
21. As a forecast buyer buying a series, I want to fill in the same template again for each window or threshold, so that each forecast carries its own values and its own ceiling.
22. As a forecast buyer, I want guidance saying that trading by informed insiders moves the price toward the truth at my expense, and that the subsidy ceiling caps what that can cost me, so that I can size the subsidy knowing the risk.

### Forecast buyer: settlement

23. As a forecast buyer, I want the Remainder (subsidy plus trade cash, minus what holders can claim) released to me as soon as a result is published, so that I don't have to wait for every holder to claim.
24. As a forecast buyer, I want to keep the whole Remainder even when it exceeds the subsidy, so that the subsidy caps my loss, not my gain.
25. As a forecast buyer, I want the resolution cost returned to me if the forecast ends Unpublished, so that I don't pay a resolver who didn't resolve.
26. As a forecast buyer, I want the Remainder rules to apply unchanged on Unpublished, so that settlement is predictable whichever way the forecast ends.
27. As a forecast buyer, I want the subsidy locked until a result is published or the forecast is settled Unpublished, so that traders can trust it is really there.

### Resolver

28. As a resolver, I want to publish Yes or No only after the observation window ends and before the deadline, so that the result reflects the whole window.
29. As a resolver, I want to publish Invalid at any time after open (for example, when the benchmark is withdrawn or its leaderboard goes dark), so that trading stops as soon as the question can't be answered.
30. As a resolver, I want to receive the resolution cost on any publication, Yes, No, or Invalid alike, so that I gain nothing by picking one result over another.
31. As a resolver, I want my published result to be final, so that the forecast settles without a dispute window. Whether this holds for AI questions is the open oracle question (see Further Notes).
32. As a resolver, I want to be unable to publish after the deadline, so that the deadline is hard for everyone.

### Trader

33. As a trader, I want to buy Yes or No shares with ETH at the LMSR cost and no trading fee, so that I pay only for the price move.
34. As a trader, I want to sell shares back at the LMSR quote while the forecast is open, so that I can exit before the result.
35. As a trader, I want a minimum-out bound on every buy and sell, so that a trade landing just before mine can't fill me at a worse price than I was quoted.
36. As a trader, I want each winning share to pay the fixed Payout, so that I know what I'm buying.
37. As a trader, I want every Yes and No share to pay half the Payout on Invalid or Unpublished, so that an unanswerable question doesn't wipe out either side.
38. As a trader who sold before publication, I want my earlier sells to be final, so that nothing is clawed back or topped up.
39. As a trader, I want my claim to never expire, so that I can collect whenever I come back.
40. As a trader, I want unclaimed payouts never swept to the forecast buyer, so that my claim is always backed.
41. As a trader, I want trading to close when the observation window ends, so that nobody trades on the observed result.
42. As anyone, I want to settle the forecast as Unpublished after the deadline when the resolver hasn't published, so that holders can claim without depending on the resolver.

### Reader of the forecast page: open

43. As a reader, I want a breadcrumb back to the buyer's question page or report, so that I know who asked the question and can go back.
44. As a reader, I want the question as the heading with a status pill, so that I know what is being forecast and whether trading is open.
45. As a reader, I want one meta line with the volume traded in ETH, the number of traders, "Funded by <forecast buyer>", and "Trading closes <window end>", so that I can judge how much money stands behind the number.
46. As a reader, I want volume measured in ETH and shown before the trader count, so that wallets created to inflate participation don't carry the signal.
47. As a reader, I want a chart of the chance of Yes and No over time, with 1W / 2W / All ranges, "Opened <date> at X% Yes" and "Today", so that I see the forecast and how far it has moved.
48. As a reader, I want one outcome row per side with its price per share, "pays <Payout> if <side>", and the chance as a large %, so that the price reads as a probability.
49. As a reader, I want picking an outcome row to pick that side in the trade box, so that I can go from reading to trading in one click.
50. As a reader, I want a "Key dates" timeline (opened, trading closes, result due), so that I know when things happen.
51. As a reader, I want a "How it resolves" card with the data source, who decides, the invalid-result rule ("Every share then pays half"), and the influence line as "Conflict of interest", so that I know who decides and which labs can move or already know the outcome.
52. As a reader, I want a "Who pays for this forecast" card saying in plain words how much the forecast buyer put up, that it pays traders who are right, what the resolution cost was and where it went, and that what is left goes back to the buyer, so that I know why someone is paying for this number.
53. As a reader, I want no Depth figure, ladder, or "subsidy ceiling" jargon on the page, so that the page explains the forecast instead of its mechanics.

### Reader of the forecast page: trade box

54. As a trader, I want Buy and Sell tabs, Yes and No buttons showing their chance, a "You pay" field in ETH, and 0.1 / 0.25 / 0.5 / 1 chips, so that I can size a trade quickly.
55. As a trader, I want receipt rows ("You get N shares", "Average price", "If <side> wins <x> (+N%)", "Chance of Yes P% → Q%"), so that I see what I get, what I can win, and my price impact before I confirm.
56. As a trader selling, I want the same box with my share count as the size and the ETH I receive in the receipt, so that selling reads the same way as buying.
57. As a trader, I want the footer "Each share pays <Payout> if its answer is right, and nothing if not. You can sell before <window end>.", so that the payout rule is always next to the button.
58. As a reader, I want the action to read "Connect wallet", "Enter an amount", "You have no <side> shares", "Price unavailable", or "Buy <side>" / "Sell <side>", so that the button always says what is missing or what will happen.
59. As a reader waiting for a quote, I want the last receipt to stay on screen dimmed (after a 150ms delay, so that fast answers never flicker) and the action disabled, so that I never act on a stale number.
60. As a reader whose quote failed, I want "Couldn't get a price. Try again" inline and the action disabled, so that I know the failure is local.
61. As a reader when the chain is unreachable, I want "Can't read this forecast right now" with Try again and no numbers at all, so that stale figures are never presented as current.

### Reader of the forecast page: after trading closes

62. As a reader after trading closes, I want the trade box replaced by a result box in the same place, so that the page keeps its shape and the result appears where the action was.
63. As a reader while the result is awaited, I want "Trading has closed", "The <resolver> publishes the answer by <deadline>. If they don't, every share pays half (<half>).", and "Result due <deadline>" in the meta line, so that I know both paths.
64. As a reader after Yes or No, I want the winning side marked and "The answer was <side>" with "Published <date>. Each <side> share pays <Payout>. <other> shares pay nothing.", and the chart ending at "Final P% Yes", so that I can compare the forecast with the result.
65. As a reader after Invalid, I want "The question was Invalid" with the reason under the invalid-result rule and "Every share pays half (<half>).", so that I see why the question failed.
66. As a reader after Unpublished, I want "No result was published" with "The resolver missed the <deadline> deadline. Every share pays half (<half>).", so that I see the resolver failed, not the question.
67. As a reader of a Withdrawn forecast, I want "This forecast was withdrawn", "No trades" in the meta line, a placeholder chart at the opening chance, outcome rows marked "Never traded", and no claim action, so that I don't read it as a tested question.
68. As a holder, I want the result box to list my shares per side with their value and a "You can claim <x>" total, so that my position sits next to the result.
69. As a holder while a result is awaited, I want each row valued "<x> if <side>" and a disabled "Claim opens when the result is in", so that I know what I may get and when.
70. As a holder after settlement, I want "Claim <x>" wherever shares pay something (Yes, No, Invalid, Unpublished) and "Nothing to claim" when mine pay nothing, with losing shares never shown as a bare 0, so that I only see a live claim when it does something.
71. As a holder without a connected wallet after close, I want "Connect your wallet to see your shares" and a "Connect wallet" button, so that I always have a way to see my position.
72. As a reader, I want the forecast buyer's Remainder figure kept off the page, so that the page is about the forecast, not the buyer's books.

### Motion and polish

73. As a reader, I want fold-outs to fade and slide in over 180ms, with the chevron rotating, so that what opens is clearly tied to what I clicked.
74. As a reader, I want the swap from trade box to result box at close to crossfade with a slight blur over 240ms, so that the change of state is noticed but not dramatic.
75. As a reader, I want buttons to press-scale to 0.97 over 160ms, so that presses feel acknowledged.
76. As a reader, I want the Buy/Sell tabs, the Yes/No pick, typing a size, and receipt changes not to animate, so that actions repeated many times a minute stay instant.
77. As a reader with reduced motion enabled, I want all of the motion above turned off, so that the page respects my setting.

## Implementation Decisions

### Positioning

- The wedge is a forecast with a price tag, on the buyer's own AI question. The worst-case cost (the subsidy ceiling plus the resolution cost) and the Depth are known before publish. Forecaster panels are priced per engagement with no stated depth. Public AI markets are thin and not on the buyer's question.
- Prior-based LMSR is how the price tag is delivered, not a claim. The influence line and the forecast page support the wedge but are not the wedge.
- Not claimed as differentiators: anyone can create markets, AMM versus order book, LP rewards, automatic objective resolution, the pricing mechanism, better accuracy than panels, and the oracle.
- The spec states openly that one named resolver is a weaker oracle than Seer's (Reality.eth plus Kleros) and TRUEO's (a bonded optimistic oracle plus a council). For fuzzy AI questions this weakness matters more than it did for grant milestones. Which upgrade they need is the open oracle question (see Further Notes). A stronger oracle can be swapped in without changing the wedge.

### Forecast contract: a new market, separate from Greenlight

- This is a new contract that sits alongside the existing bonding-curve contracts. Greenlight's contracts, tests, deploy script and UI stay unchanged so they can be inspected. This spec does not decide their fate.
- One contract instance is one forecast. Publishing a forecast means deploying it, or creating it through a factory, with every value set at publish and the subsidy plus resolution cost sent as value in the same transaction.
- **Values set at publish, all immutable:**
  - the buyer address and the resolver address;
  - the opening probability;
  - the maximum subsidy, the resolution cost and the Payout;
  - the four pins (data source, observation window, deadline, invalid-result rule);
  - the influence line.
- **Publish validation:**
  - the resolver is not the buyer;
  - the opening probability is a whole number of points from 10 to 90 inclusive;
  - the subsidy, resolution cost and Payout are non-zero;
  - the attached ETH equals the subsidy plus the resolution cost;
  - the influence line and all four pins are non-empty;
  - the observation window ends after publish, and the deadline comes after the window ends.
- **Outcomes:** two tradable outcomes, Yes and No. Invalid is a published status with no shares and no price.
- **Shares:** Yes and No shares are fungible tokens. There is no per-account accounting beyond token balances.
- **Cost function:** the two-outcome prior-based LMSR (Chen and Pennock, UAI 2007, eq. 15; Hanson 2003).
  - With opening probability π, the cost of a share vector q is b · ln(π_Yes · e^(q_Yes/b) + π_No · e^(q_No/b)), measured in shares. Multiply by the Payout to get ETH.
  - The price of an outcome is its share of that sum.
  - A buy or sell costs the difference between the cost before and after.
- **Liquidity parameter:** b = S / (Payout × ln(1 / min(p, 1−p))), in shares, where S is the maximum subsidy.
  - It is computed once at publish.
  - This makes S the hard worst-case trading loss. Entropy is the expected loss, not the ceiling.
- **Rounding:** every fixed-point exp or ln result and every quote rounds in the contract's favour, so that rounding can never push the buyer's loss above S. The solvency invariant always holds: the contract balance is at least what holders can claim plus the escrowed resolution cost.
- **Trading:**
  - Buy with an exact ETH amount and a minimum share count.
  - Sell a share amount with a minimum ETH amount.
  - There is no trading fee. Traders pay only the LMSR cost.
  - There is no restriction on who trades, including Interested parties and the buyer.
- **Total traded:** a running sum of the ETH spent on buys plus the ETH paid out on sells. It drives the page's volume figure and gates Withdrawn.
- **Depth:** computed from S and p.
  - Up = S × ln((1−p)/(0.95−p)) / ln(1/min(p, 1−p)).
  - Down = S × ln(p/(p−0.05)) / ln(1/min(p, 1−p)).
  - The Payout cancels out of both. At 50% each direction is 15.2% of S. At 10% it is 2.5% of S up and 30.1% down.
  - Both figures are readable from the contract, or derivable from immutable values, and never change.
  - A direction that would cross 0% or 100% is omitted. That can't happen inside the 10–90 range, but the display rule stands.
  - At exactly 50% the two figures are equal and shown as one.

### Lifecycle and permissions

| State | Entered when | Who can act |
|---|---|---|
| Open | publish | anyone buys or sells; the resolver may publish Invalid; the buyer may withdraw only while total traded is zero |
| Awaiting result | the observation window ends with nothing published | the resolver publishes Yes, No, or Invalid before the deadline |
| Yes / No / Invalid | the resolver publishes | holders claim; final |
| Unpublished | after the deadline, anyone calls settle | holders claim |
| Withdrawn | the buyer withdraws before any trade | nothing |

- Invalid can be published at any time from publish until the deadline. Publishing it ends trading immediately.
- Yes and No can only be published between the end of the window and the deadline.
- After the deadline, the resolver can't publish.
- No state changes after Yes, No, Invalid, Unpublished, or Withdrawn. There is no correction and no dispute window, unless the open oracle question adds one.

### Settlement money flows

- **On publication of Yes, No, or Invalid:**
  - Set aside exactly what holders can claim. On Yes or No that is Payout × outstanding winning shares. On Invalid it is ½ Payout × all outstanding Yes and No shares.
  - Pay the resolution cost to the resolver.
  - Send the Remainder (subsidy + trade cash − set-aside) to the buyer straight away.
- **On Unpublished:** the set-aside is the same as for Invalid, and the Remainder goes to the buyer. The resolution cost also goes back to the buyer.
- **On Withdrawn:** the subsidy and the resolution cost go back to the buyer. The resolver is paid nothing.
- **Claims:** a claim burns the holder's shares and pays the per-share amount for the settled state. Claims never expire, and an unclaimed set-aside is never swept.
- **Remainder above the subsidy:** the buyer keeps all of it. The subsidy caps loss, not gain.
- **Invalid's loss bound:** a 50/50 split keeps the buyer's loss at or below b × KL(½‖π) ≤ S. At a 50% opening, the buyer loses nothing on Invalid.
- **Events:**
  - publish;
  - trade (side, direction, ETH, shares, probability after);
  - publication (result, date);
  - Unpublished settlement;
  - withdrawal;
  - claim.

  The page reads its dates, states, and chance history from these events.

### Trust assumptions (stated in the spec, not enforced)

- **Resolver:** the contract only rejects a resolver equal to the buyer. A buyer could still name a second wallet or a friendly multisig. Readers rely on the resolver's identity.
- **Interested parties:** for AI questions these are the labs whose staff can bring the result about (by shipping or holding back a model) or already know it (an internal release date). Insider bets on model-release dates are documented. Nothing onchain limits who trades. A blocklist is cheap to dodge with a fresh wallet, so the influence line is the disclosure.
- **No contractual lever:** unlike a grant, the buyer has no agreement with the labs, so there is no recommended trading clause and no penalty route. The grant-clause and tranche guidance from the earlier spec is dropped.
- **What insider trading costs:** an informed insider moves the price toward the true result, which is the information the buyer is paying for, and takes the gain out of the subsidy. The ceiling S caps that cost. Guidance to the buyer: size S as the price of the forecast, assuming the best-informed traders take most of it.
- **Breaches:** a result stands whoever traded. Invalid stays reserved for the question's own invalid-result rule.

### Forecast page

- **A pure view of three inputs:**
  - forecast state and numbers: state, current and opening probability, the chance history, total traded, trader count, subsidy, resolution cost and where it went, Payout, pins, resolver, influence line, and dates;
  - wallet: none, connected with no shares, or holding, plus the holdings;
  - quote status: live, pending, error, or chain down.

  A thin adapter reads the contract and its events into the forecast input, and the chance history comes from the trade events. Quotes are computed with the same LMSR maths as the contract, or read from the contract's view functions, so the receipt matches executed fills.
- **Units:** probability is shown as a whole percentage and money in ETH. This departs from Greenlight's cents board (ADR 0002), which stays on the Greenlight pages. The `number-formatting` skill does not apply to this page.
- **Layout (as decided for the Seer-style page):** a breadcrumb back to the buyer's question page or report, then two columns.
  - Left: a header card (status pill, question, meta line, chance chart), an outcomes card with one row per side, "Key dates" beside "How it resolves", and "Who pays for this forecast".
  - Right, sticky: the trade box while trading is open, the result box after.
- **Trade box:** Buy and Sell tabs, Yes and No, a "You pay" ETH field with preset chips, the receipt rows, the action, and the payout footer.
- **Result box:** the same position and size as the trade box. It shows a heading and one body line for each state, the holdings with a claim total, and the claim action. The copy is as in the user stories above.
- **Depth:** stays a contract figure and the buyer's number at publish (see the positioning sentence). The reader page does not show it.
- **Rejected:** the 380px embedded panel; a host page with a compact card and a side drawer for trading; a guided three-step ticket; holdings in a tab or a separate card.
- **Look:** carried from the Greenlight columns direction:
  - paper and ink, 6px radius, tabular figures;
  - Yes green `#2ecc71` and No red `#e74c3c` only on outcome marks (dots, chart lines, the winning mark), never filling a card;
  - ink and ghost buttons.
- **Motion:** one ease-out curve, `cubic-bezier(0.23, 1, 0.32, 1)`:
  - fold-outs: 180ms;
  - close swap: 240ms with a slight blur;
  - pending dim: after a 150ms delay;
  - press scale: 0.97 over 160ms;
  - none of it applies under reduced motion.
- **Surface:** a page of its own, served by this repo and linked from the buyer's question page or report. Whether the buyer also wants a component it can embed is still open (see Further Notes).

## Testing Decisions

A good test exercises behaviour only through the public seam: for the contract, calls and balances; for the forecast page, the inputs it is given and what renders. Tests never reach into storage layouts, internal helpers, or component internals. There are two seams.

### Seam 1: the forecast contract's external interface (Foundry)

Prior art: the checkpoint tests in the existing PredictionMarket Foundry test file (setUp with named actors, `vm.prank`, `vm.deal`, `vm.warp`, `expectRevert` on custom errors, balance deltas). Use a new test file and leave the Greenlight tests alone.

- **Publish validation:** each refused input is rejected:
  - the resolver equals the buyer;
  - the opening probability is outside 10–90 or not a whole number;
  - an amount is zero;
  - the attached value is wrong;
  - a pin or the influence line is empty;
  - the window or deadline is in the wrong order.
- **Loss ceiling:**
  - Fuzz sequences of buys and sells, then publish each result. The buyer's Remainder is never below (subsidy − S), and the contract stays solvent for every claim.
  - The worst case approaches S but never exceeds it.
  - Cover 10%, 30%, 50% and 90% openings.
- **Depth:** the ETH needed to move 5 points at the open matches the formula within rounding (15.2% of S at 50%; 2.5% and 30.1% at 10%) and does not depend on the Payout.
- **Quotes:**
  - Buy and sell honour their minimum-out bounds.
  - Selling right after buying never returns more than was paid.
  - There is no fee.
- **Timing:**
  - No trading after the window ends or after Invalid.
  - Yes and No can't be published before the window ends.
  - The resolver can't publish after the deadline.
  - Anyone can settle Unpublished, but only after the deadline.
- **Payouts:**
  - Yes and No pay the full Payout to winners and nothing to losers.
  - Invalid and Unpublished pay half per share.
  - Only shares held at publication are paid.
  - Claims work long after settlement.
  - Unclaimed funds stay claimable.
- **Resolution cost and Remainder:**
  - The resolver is paid the same amount on Yes, No and Invalid.
  - The cost goes back to the buyer on Unpublished and Withdrawn.
  - The Remainder is paid at publication and may exceed the subsidy.
- **Withdrawn:**
  - Allowed only while total traded is zero, and refused after the first trade.
  - Returns both amounts and blocks all further actions.
- **Immutability:** no function changes any value set at publish, and there are no top-ups.

### Seam 2: the forecast page as a pure view of (forecast state, wallet, quote status)

Prior art: the throwaway prototypes `prototype/forecast-panel`, `prototype/forecast-closed`, `prototype/forecast-product` and `prototype/forecast-seer`. Variant A of `prototype/forecast-seer` is the chosen layout. They already switch through `state`, `wallet` and `quote`. The copy in them still refers to a grant breadcrumb and must be changed to the buyer's question page. Checks run with `playwright-cli`.

- Every combination of state (open, awaiting, yes, no, invalid, unpublished, withdrawn) × wallet (none, empty, holding) × quote (live, pending, error, down) renders the decided copy and actions:
  - the trade box only while trading is open, and the result box otherwise;
  - the claim action only where shares pay;
  - on Withdrawn, no holdings and no claim, with "No trades" and the opening chance;
  - losing shares never shown as a bare 0;
  - no numbers when the chain is down.
- The resolver, the invalid-result rule, and the influence line are present in every state.
- The receipt (shares, average price, win amount, chance after) matches a quote computed against the contract for the same size.
- The chart starts at the opening probability and ends at the current one, or at the probability at close.
- Under reduced motion, nothing animates. The tabs, the Yes/No pick, typing, and receipt changes never animate.
- On a narrow screen the page reads in one column, with the trade box after the header.

## Out of Scope

- Running the demand test, and choosing the buyer's first real question.
- Removing or rewriting the bonding-curve contracts, tests, deploy script, or Greenlight UI.
- Rewriting the Greenlight glossary.
- A marketplace or a general betting exchange.
- Any claim of better accuracy than forecaster panels or public markets.
- A forecast that compares several candidates in one market. A series or a multi-candidate question becomes several separate binary forecasts, each with its own subsidy.
- A buyer layer on top of Seer, Polymarket or Kalshi. Seer would bring its fully paying tradable Invalid token, Reality.eth bond timing, and pool depth that depends on the price range, all of which were rejected. The public venues don't let the buyer set the question or the depth.
- AI economic-impact questions (the runner-up wedge) as a first target. The template allows them, but this spec doesn't tune its guidance for them.
- A tradable Invalid outcome, top-ups or co-funder roles after publish, a trading fee, LP rewards, an opening lock, and onchain enforcement against Interested parties.

## Further Notes

- **Demand test before building** (ticketed as [Whether forecast buyers answer the demand test](issues/14-whether-forecast-buyers-answer-the-demand-test.md)). Send the five drafts in [the outreach asset](../buyer-and-wedge/assets/05-outreach.md) to Coefficient Giving, FRI, Anthropic Economic Futures, OpenAI Economic Research and Metaculus, plus Renaissance Philanthropy as a sixth target. Wait two weeks, with one follow-up.
  - **Pass:** at least one "pay" with an amount, at least one "maybe", or Metaculus agrees to talk as a channel. This spec then becomes ready-for-agent.
  - **Fail:** everyone says no or doesn't reply. Record "no buyer" and stop the venture track. This spec is then shelved.
- **Evidence behind the pick is weak.** The only in-window payment is the $58K Metaculus FutureEval prize pool, which paid forecasters and did not buy information. Coefficient Giving's payments to FRI are 13+ months old.
- **Regulation.** The CFTC issued an interim final rule on 2026-10-09. Information-only questions like these fit its "hedging utility" test less well than hedging niches do. Who can trade, and from where, is not settled here.
- **Open questions:**
  1. **Oracle** (ticketed as [Which oracle AI capability and release questions need](issues/16-which-oracle-ai-capability-and-release-questions-need.md)). Which oracle or dispute upgrade fuzzy AI capability and release-timing questions need: one named resolver as now, a committee, or a bonded optimistic oracle with a dispute window. It must be decided before building. It may change the resolver stories, the "results are final" rule, and the lifecycle table.
  2. **Currency.** Funders budget in dollars. Can the buyer pay in a stablecoin, or must it pay in ETH, with a dollar label shown only as a label? Only the ETH amount can actually be drawn.
  3. **Hosting.** Whether the buyer wants only a link to a page this repo serves, or also a component to embed in its own report.
  4. **Remainder.** Where the buyer sees and claims the Remainder after settlement, now that the page leaves it off: a buyer-only view, or the buyer's own records.
- **Before writing Solidity:** apply https://ethskills.com/SKILL.md. Do not POST to its feedback endpoint without asking the human.
- **Research and prototypes (local branches only, no remote):**
  - `research/lmsr-subsidy-bound`: the LMSR bound and its sources.
  - `research/long-tail-niches`: AI-question payers and how thin the incumbents are.
  - `research/ai-agent-arenas`: evidence of insiders betting on release dates.
  - `research/seer-trueo`: the comparison with Seer and TRUEO.
  - `research/protocol-forecast-demand`: the earlier buyer's demand evidence, now superseded.
  - `prototype/forecast-panel`, `prototype/forecast-closed`, `prototype/forecast-product`: the earlier panel decisions.
  - `prototype/forecast-seer`: the chosen forecast page (variant A).
- **Glossary:** the Budgeted forecast section of `GLOSSARY.md` holds this spec's terms (Invalid, Awaiting result, Depth, Unpublished, Withdrawn, Interested party, Remainder), and the Buyer and wedge section holds Forecast buyer. Payout and Trade cash keep their Greenlight meanings.
