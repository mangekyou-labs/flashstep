# How the forecast panel feels as one product

Label: wayfinder:prototype
Type: prototype
Status: closed
Assignee: MrSufferer

## Question

Does the decided forecast panel hold up as one product when a reader actually uses it? Rebuild it as a single polished prototype covering the full lifecycle: open, awaiting result, Yes, No, Invalid, Unpublished, Withdrawn. It should sit inside a mock grants dashboard at about 380px wide. Use it to decide:

1. **Where a trader sees their holdings and sell quotes**, now that the open panel quotes buying only ([How the open forecast panel reads](06-how-the-open-forecast-panel-reads.md)). The choice is inside the panel once a wallet is connected, or a separate view. This graduates that patch from Not yet specified.
2. **How the panel moves between interactions and states.** That covers the Yes/No toggle, typing a size, opening the "More sizes" fold-out, and the swap from quote to status and payout at close ([How the panel reads after trading closes](10-how-the-panel-reads-after-trading-closes.md)). Decide which of these animate, how they animate, and which deliberately don't.
3. **What the panel shows before a wallet connects, while a quote is pending, and on error.** The earlier prototypes stubbed these states.

The layout and copy from [How the open forecast panel reads](06-how-the-open-forecast-panel-reads.md) and [How the panel reads after trading closes](10-how-the-panel-reads-after-trading-closes.md) are settled. Keep them unless using the prototype exposes a real problem. Record any such problem in the answer instead of quietly changing the layout.

## Starting material

- The Greenlight market prototype in the working tree, `packages/nextjs/app/prototype/market/`, is the visual baseline. Its chosen direction is the **columns** variant (`MarketColumns.tsx`). Tape and desk were rejected. Do not borrow from them. Keep its locked look: paper and ink, 6px radius, tabular figures, and Yes green `#2ecc71` / No red `#e74c3c` only on outcome marks. Outcome color never fills the panel. Reuse `paperChrome.ts`, `tokens.ts` (ink and ghost buttons, 160ms transform-only press, field styles), and `PrototypeSwitcher`. Drop its bonding-curve fixture, 50 bps fee, oracle, race joke, and Greenlight wordmark. Copy into the new route. Do not edit the market prototype.
- The Greenlight portfolio surface was the next planned section of that effort: open marks, redeemable ETH after close, empty and disconnected states. It was never built. Its state list is a useful checklist for question 1. Its cents-and-bonding-curve copy is not: this panel speaks in probability % and ETH, as decided on this map.
- `prototype/forecast-panel` (52628a6) has the headline variant: open-state layout and LMSR quote math.
- `prototype/forecast-closed` (d28526d) has the swap variant: closed-state copy for every state.
- Source handoff: `/var/folders/f3/vyr34p2x2hb0239kv43c2dc40000gn/T/greenlight-ui-next-section-handoff.md` (2026-10-17, Greenlight UI effort). It predates the 2026-10-19 redraw of this map. Its look rules apply here. Its scope rules don't: the fold onto `/market`, Greenlight terms, and the bonding-curve market.

## Leave alone

- The market prototype, its tape and desk variants, the picker, `Header`, `Footer`, `globals.css`, `components/constants.ts`, Solidity, Foundry tests, the deploy script, the spec, `GLOSSARY.md`, and the ADRs.
- Do not call the `number-formatting` skill. Its rules conflict with this map's probability and ETH display.
- Browser checks use `playwright-cli` only. If a dev server or a `playwright-cli` session named `greenlight` is running, don't kill either.

## Before building

Call the Skill tool with "emil-design-eng" and follow it for motion, component polish, and interaction details. Call "prototype" to build. Throwaway: branch `prototype/forecast-product`, route `packages/nextjs/app/prototype/forecast-product/`, states via `?state=`, wallet via `?wallet=none|empty|holding`. Never merged. Nothing is sent to the chain. Load the prototype skill's `PICKER.md` before building the harness. After it renders, use `playwright-cli` to flip every state and wallet combination before stopping for the human's choice.

## Answer

### Amended 2026-10-19: the Seer-style forecast page (variant A)

The first-time reader could not follow the 380px panel. It opened on mechanics (Depth, subsidy ceiling, a quote sentence) before it said what the forecast was. The forecast is now a full page laid out like Seer's market page. Where this section and the original answer below disagree, this section wins.

- **Layout.** A breadcrumb back to the grant ("<sponsor> › Grants › <grant> › Forecast"). Two columns: the content on the left, a sticky box on the right (the trade box while open, the result box after).
- **Header card.** Status pill, the question as the heading, one meta line (volume in ETH, traders, "Funded by <sponsor>", "Trading closes <window end>" or "Result due <deadline>"), and a chance-history chart. The chart has Yes and No lines, an axis fitted to the data, 1W / 2W / All tabs, "Opened <date> at X% Yes" on the left, and "Today" or "Final P% Yes" on the right.
- **Outcomes card.** One row per side: a colour dot, the name, "<price> per share · pays <Payout> if <side>", the chance as a large %, and a radio that picks the side in the trade box.
- **Trade box.** It replaces the one-sentence quote and the per-row inline sell form.
  - Buy / Sell underline tabs, Yes / No buttons with their %, a "You pay" ETH field, and 0.1 / 0.25 / 0.5 / 1 chips.
  - Receipt rows: "You get N shares", "Average price", "If <side> wins <x> (+N%)", and "Chance of Yes P% → Q%".
  - The action reads "Connect wallet", "Enter an amount", "You have no <side> shares", "Price unavailable", or "Buy <side>" / "Sell <side>".
  - Footer: "Each share pays <Payout> if its answer is right, and nothing if not. You can sell before <window end>."
  - Quote error: "Couldn't get a price. Try again." Chain down: "Can't read this forecast right now" with Try again, and no numbers.
- **Result box (all closed states).** A heading by state ("Trading has closed", "The answer was Yes", "The question was Invalid", "No result was published", "This forecast was withdrawn"), one body line with the date and the payout per share, then the holdings: "<n> <side> shares <x>" per side and a "You can claim <x>" total.
  - Awaiting: values read "<x> if Yes" and the action is a disabled "Claim opens when the result is in".
  - Settled: "Claim <x>", or "Nothing to claim".
  - No wallet: "Connect your wallet to see your shares" and a "Connect wallet" button.
  - Withdrawn: no holdings and no button.
- **Below the outcomes.** A "Key dates" timeline (opened, trading closes, result due, published or withdrawn) next to "How it resolves" (resolves using <source>, who decides, "If the data breaks: <invalid-result rule> Every share then pays half.", conflict of interest = the influence line). Then a "Who pays for this forecast" card in plain words: the sponsor put up to <subsidy> behind the forecast, that money pays traders who are right, and what is left goes back to the sponsor. It must also state the resolution cost and where it went; the prototype left that out.
- **Withdrawn.** Meta reads "No trades · Funded by <sponsor> · Withdrawn <date>". The chart is a dashed placeholder at the opening chance. Outcome rows show the opening chance with "Never traded". Key dates show only Opened and Withdrawn.
- **Dropped from the primary view.** The Depth line, the "More sizes" ladder, and the words "subsidy ceiling". Depth stays a contract figure and a sponsor-side number at publish; the reader page does not show it.

Still stands from the answer below: the motion rules (one ease-out curve, 150ms-delayed pending dim, 180ms fold-outs with the chevron, 240ms close swap with blur, 0.97 press), no motion on the Yes/No toggle, typing, or quote text, everything off under reduced motion, losing shares never shown as a bare 0, and no numbers when the chain is down.

Rejected: variant B (the grant page with a compact card and a side drawer for trading) and variant C (a guided three-step ticket in one column).

Prototype: branch `prototype/forecast-seer` (commit 9b9d615, local only), route `packages/nextjs/app/prototype/forecast-seer/`. Variants via `?variant=A|B|C`, states via `?state=`, wallet via `?wallet=none|empty|holding`, quotes via `?quote=live|pending|error|down`, motion via `?motion=off`. Removed from main's working tree.

### Original answer (superseded where the section above differs)

Inside the panel. Holdings and sell quotes live in the same card, below the quote or the status, once a connected wallet holds shares. Motion is small and only on things the reader opens or waits for.

- **Holdings ("Your shares").** The section appears only when the connected wallet holds shares. Each side gets one row with the share count and what those shares are worth:
  - Open: "<x> if sold now".
  - Awaiting result: "pays <x> if Yes · <y> if Unpublished" (mirrored for No).
  - Settled: "pays <x>", or "pays nothing" for losing shares.
  - Withdrawn: no shares were ever issued, so there is no section.
- **Sell.** While open, each row has a Sell action. It opens an inline form with a size field and a one-sentence quote: the ETH received and the probability move, in the same form as the buy quote. This answers "sell quotes live with holdings" from [How the open forecast panel reads](06-how-the-open-forecast-panel-reads.md).
- **What animates.** All motion uses one ease-out curve, `cubic-bezier(0.23, 1, 0.32, 1)`.
  - A pending quote dims after a 150ms delay. Fast answers never flicker.
  - The "More sizes" fold-out and the sell form fade and slide in over 180ms. The chevron rotates.
  - The quote-to-status swap at close crossfades with a slight blur over 240ms.
  - Buttons press-scale to 0.97 over 160ms.
- **What deliberately doesn't animate.** The Yes/No toggle, typing a size, and the quote text changing. These are repeated many times a minute.
- **Reduced motion.** Everything above is turned off under reduced motion.
- **Before a wallet connects.** Numbers stay readable. The action becomes an ink "Connect wallet" button:
  - "Connect wallet to buy" while open.
  - "Connect wallet to see your shares" while awaiting a result.
  - "Connect wallet to claim" once settled.
- **Quote pending.** The last quote stays on screen, dimmed, and the Buy button is disabled. With no previous quote, it reads "Getting a quote…".
- **Quote error.** "Couldn't get a quote. Try again" replaces the sentence inline, and Buy is disabled.
- **Chain unreachable.** The panel shows "Can't read this forecast right now" with Try again. It shows no numbers, so stale figures are never presented as current.

Problems that using the prototype exposed:

- **The top of the open panel was too heavy.** Recorded as an amendment to [How the open forecast panel reads](06-how-the-open-forecast-panel-reads.md), approved by the human:
  - The depth-at-open line moves into the "More sizes" fold-out, under the ladder.
  - The facts row wraps between items rather than inside them.
  - The headline is one step smaller.
- **Awaiting result with no wallet had no action at all.** That left a holder no way to see their position. Fixed with "Connect wallet to see your shares".
- **Losing shares need explicit words.** They read "pays nothing", never a bare 0.

The variant with holdings in a tab and the variant with holdings in a separate card under the panel were rejected. The tab hides your position behind a click on the same 380px card. The separate card splits one product into two surfaces.

Prototype: branch `prototype/forecast-product` (commit 9699592, local only), route `packages/nextjs/app/prototype/forecast-product/`. Variants via `?v=1|2|3`, states via `?state=open|awaiting|yes|no|invalid|unpublished|withdrawn`, wallet via `?wallet=none|empty|holding`, quotes via `?quote=live|pending|error|down`, motion via `?motion=off`. All are flipped from the prototype controls card. That card replaces PICKER.md's plain state strip, which the human found unreadable. Removed from main's working tree.

## Comments

- 2026-10-19: Reopened to review the `prototype/forecast-product` prototype against the new handoff spec (`../spec.md`). The answer above stands until this review records a change. Any amendment is recorded here, and the spec is updated to match.
- 2026-10-19: Reviewed. The human found the panel unreadable for a first-time reader and asked for a Seer-style rebuild. Three variants were built (A: market page, B: grant page with a drawer, C: guided ticket). The human chose A. The amendment is recorded at the top of the answer, and `../spec.md` is updated to match. Closed again.
