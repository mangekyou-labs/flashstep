# How the panel reads after trading closes

Label: wayfinder:prototype
Type: prototype
Status: resolved
Assignee: MrSufferer

## Question

How should the embedded forecast panel read once trading has closed? Cover each state: Awaiting result (window ended, nothing published yet), published Yes, published No, published Invalid (including Invalid published early, which ends trading), Unpublished (deadline passed, settled by anyone), and Withdrawn (sponsor took it down before any trade; see [Whether subsidy and opening probability can change after publish](07-whether-subsidy-and-opening-probability-can-change-after-publish.md)).

Start from the open layout decided in [How the open forecast panel reads](06-how-the-open-forecast-panel-reads.md): headline probability, a traded / subsidy / resolution cost row, the depth-at-open line, a buy quote sentence, and the resolver in the footer. Decide what replaces the quote in each state, what the headline shows (last traded probability, the result, or both), and how the payout per share is stated (full Payout for a winning share; half for Invalid and Unpublished, per [What traders and the sponsor are paid at resolution](03-what-traders-and-the-sponsor-are-paid-at-resolution.md)).

Already settled: Unpublished shows the last probability frozen, and the resolver is always named ([Who is paid the resolution cost](04-who-is-paid-the-resolution-cost.md)). The influence line is always shown next to the resolver ([What the forecast says when a trader can move the outcome](09-what-the-forecast-says-when-a-trader-can-move-the-outcome.md)).

## Before building

Apply https://ethskills.com/SKILL.md and follow it before writing Solidity or shipping anything onchain. Do not POST to its feedback endpoint without asking the human.

## Answer

Swap. The panel stays the same card from open to settled. The headline and the quote are swapped by state. Nothing else moves.

- **Headline by state.**
  - Awaiting result and Unpublished: the last probability, dimmed, labelled "chance Yes, frozen at close".
  - Yes, No and Invalid: the result word (Yes in green, No in red), with "forecast said 46.0% Yes at close" beside it.
  - Withdrawn: the word Withdrawn, with "opened at 40.0% · never traded".
  - The corner reads "Result due <deadline>" while awaiting, and "Closed" otherwise.
- **Facts row.** Traded, subsidy ceiling, and resolution cost. Under the resolution cost is a line saying where it went:
  - "escrowed" while awaiting;
  - "paid to resolver" after Yes, No or Invalid;
  - "returned to sponsor" after Unpublished or Withdrawn.
  - Withdrawn shows 0 traded.
- **The quote is replaced by a status line and a payout line.**
  - Awaiting result:
    - Status: "Trading closed <window end>. The resolver publishes the result by <deadline>."
    - Payout: "A winning share will pay <Payout>. If nothing is published by <deadline>, every share pays <half>."
  - Yes or No:
    - Status: "Published <date> by the resolver. Final."
    - Payout: "Each Yes share pays <Payout>. No shares pay nothing." (mirrored for No)
  - Invalid:
    - Status: "Published <date> by the resolver under the rule: <invalid-result rule>"
    - Payout: "Every Yes and No share pays <half>, half the Payout."
  - Unpublished:
    - Status: "No result by <deadline>. Settled as Unpublished on <date>."
    - Payout: the same as Invalid.
  - Withdrawn:
    - Status: "The sponsor withdrew this forecast on <date>, before anyone traded."
    - Payout: "No shares were ever issued."
- **Claim action.** Shown wherever shares pay something (Yes, No, Invalid, Unpublished). Never shown while awaiting or Withdrawn.
- **Footer.** The resolver and the influence line, unchanged from the open panel.
- **What the sponsor gets back (the Remainder) is not on the panel.** The panel is for traders and the community, and that figure is the sponsor's. Where the sponsor sees it moves to Not yet specified.

The scorecard variant (forecast-at-close tile next to a result tile, plus a money table) and the timeline variant (sparkline plus life-cycle steps) were rejected. The timeline brings back a chart the open panel left out.

Prototype: branch `prototype/forecast-closed` (commit d28526d, local only), route `packages/nextjs/app/prototype/forecast-closed/`. Variants via `?variant=swap|scorecard|timeline`, states via `?state=awaiting|yes|no|invalid|unpublished|withdrawn`. Removed from main's working tree.
