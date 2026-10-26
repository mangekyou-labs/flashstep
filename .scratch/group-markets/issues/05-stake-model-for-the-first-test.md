# Stake model for the first test

Label: wayfinder:grilling
Type: grilling
Status: closed
Assignee: MrSufferer
Blocked by: 01, 02, 03

## Question

What do members stake in the first test, and how is it priced? Choose between offchain points, testnet tokens onchain, or another option, and between a pari-mutuel pot and a small LMSR. Say whether the first test is onchain at all, and what that costs in onboarding friction inside Zalo.

Lead candidate to test against: Pumpcade's model, a pari-mutuel pot with time-weighted shares (1.0x in the first 10% of the window, decaying to 0.2x) so members don't all wait for the last second. Decide whether it holds up with 5–30 people and windows of a few minutes, and what happens when one side is empty.

## Resolution

Decided in a grilling session on 2026-10-24.

- **Not onchain.** Stakes are offchain Points with no value outside the app: they cannot be bought, cashed out, traded or given as prizes, and the product copy bans settling up off-app. Joining costs only opening the mini app: no wallet, no gas. Why: Zalo bans unlicensed crypto and external login, wallets in the webview are unconfirmed, points are the most defensible option legally, and a chain adds friction without testing the riskiest assumption.
- **Pari-mutuel Pot.** Winners split the whole pot in proportion to their stakes. The house takes nothing and creators earn nothing, so the test measures question creation that no reward prompted. The prior-based LMSR doesn't carry over: with points, its subsidy would be an arbitrary number, and at 5–30 people the price would mostly reflect that number.
- **2–6 Outcomes**, with Yes/No as the default.
- **Hard Cutoff, no time weighting.** The creator sets the Cutoff when posting and may bring it forward ("Cut off now") but never push it back. Every stake counts the same. Pumpcade's 1.0x→0.2x weighting solves late betting on a continuously moving market cap. Group questions have a moment when the answer starts to show, so a Cutoff before that moment does the job directly. Stake timings are logged so the first test can see whether people wait until the last moment.
- **Stakes:** at least 10 points, no maximum, top-ups allowed before the Cutoff, no withdrawals, more than one outcome allowed. Creators may stake on their own markets. That goes to Resolution and dispute game.
- **Points per group:** 1,000 when a member first opens the app from that group, a daily top-up back to 100 if they fall below it, no reset during the test, and a group leaderboard as the only reward.
- **Every stake comes back** when the market is Unmatched (fewer than two outcomes staked at the Cutoff), when the winning outcome has no stakes, or when it ends Invalid or Unpublished. "Invalid pays half" from the budgeted-forecast map doesn't carry over to group markets.
- **Display:** before the Cutoff, each outcome shows its share of the pot as a whole-number percent plus the current multiplier ("Yes 62% · ×1.6"), marked as moving. With no stakes yet, it shows "—". Payouts round down to whole points and the leftovers are discarded.

New glossary terms: Points, Pot, Outcome, Unmatched, Cutoff. No ADR.
