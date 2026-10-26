# One buyer and one wedge

Label: wayfinder:grilling
Type: grilling
Status: resolved
Assignee: MrSufferer
Blocked by: 05

## Question

From the surviving candidates and [What payers say when asked](05-what-payers-say-when-asked.md), name one buyer and one wedge. Say which spec gets written next: resume the paused budgeted-forecast map, or start a new spec. Decide by 2026-11-03 even if the evidence is incomplete. Record the answer as an ADR if it is hard to reverse.

## Answer

**Provisional pick: candidate F.** The buyer is a forecast buyer, led by **Coefficient Giving**. The wedge is **AI capability and release-timing questions** (benchmark thresholds, model-release dates), sold as a forecast on the funder's own question and produced by a funded market. **No spec gets written next.** The next effort is a demand gate, and a new spec starts only if the gate passes. Neither the paused budgeted-forecast map nor a new spec starts now. Decided 2026-10-20, ahead of the 2026-11-03 deadline.

- **Why provisional:** F passed the kill rule weakly. Its only in-window payment is the $58K Metaculus FutureEval prize pool, which went to forecasters and was not a purchase of information. [What payers say when asked](05-what-payers-say-when-asked.md) produced zero direct buyer signals because outreach was skipped. The Notes make demand evidence the gate, so the pick waits on the gate.
- **Buyer:** Coefficient Giving is the strongest repeat buyer of forecasts (FRI panels, a Metaculus Pro commission, a forecasting grant program). It would pay again because its AI-governance grants keep re-asking AI-timing questions. Renaissance Philanthropy was the alternative: in-window, but a single data point on economic impact. The labs were the other alternative, but they gave credits, not cash.
- **Wedge:** capability and release-timing questions resolve faster and against cleaner sources than AI economic-impact questions, which are the runner-up.
- **Demand gate (the next effort):**
  - Send the five drafts in [the outreach asset](../assets/05-outreach.md), plus Renaissance Philanthropy as a sixth target.
  - Wait two weeks, with one follow-up.
  - **Pass:** at least one "pay" with an amount, at least one "maybe", or Metaculus agrees to talk as a channel. The spec then starts.
  - **Fail:** everyone says "no" or doesn't reply. Record "no buyer" and stop the venture track, with no hunt for a new candidate.
- **Open question for F's spec:** which oracle or dispute upgrade capability questions need. Benchmark scores and release dates are fuzzy, judgment-based questions.
- **Side effects:**
  - The [budgeted-forecast map](../../budgeted-forecast/map.md) is marked abandoned and kept as prior art (LMSR, subsidy ceiling, resolver).
  - The Greenlight bonding-curve code stays untouched, and F's spec decides its fate if that spec starts.
  - There is no ADR: the pick is provisional and the gate can reverse it.

## Gate result 2026-10-20

**Fail: no buyer.** The pick of F is withdrawn, and the venture track stops. The budgeted-forecast spec is shelved as prior art. See [Whether forecast buyers answer the demand test](../../budgeted-forecast/issues/14-whether-forecast-buyers-answer-the-demand-test.md).
