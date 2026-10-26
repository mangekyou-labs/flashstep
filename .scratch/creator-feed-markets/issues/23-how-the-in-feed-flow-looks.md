# How the in-feed flow looks

Label: wayfinder:prototype
Type: prototype
Status: closed
Blocked by: none
Assignee: MrSufferer

## Question

How does a creator market look and behave inside a Farcaster mini app embed, from opening it to claiming? Prototype the flow with the pricing fixed in [Creator fee and pricing](21-creator-fee-and-pricing.md): open a market (pick the asset, the window and the split for the opening stake), share the embed, stake Yes or No before the Cutoff, watch the window run, settle, and claim or get a refund (Tie, Unmatched, Expired). Decide what fits in the embed versus the opened mini app, and how the board shows each side's share of the pot and the payout a stake would get.

## Resolution

The user picked the **One-card ticket** variant out of three (one-card ticket, chart-first Up/Down, lobby with tabs).

- **Embed vs mini app.** The Mini App spec allows only a 3:2 image and one launch button (title of up to 32 characters) in the feed, and the client caches both. So nothing is interactive in the feed: staking, settling and claiming all happen in the opened mini app (about 424×695).
- **Embed.** A plain poster showing the question, a Yes/No bar with each side's share of the pot, the pot size, and the Cutoff as an absolute clock time in UTC. It has no countdown, because the image is cached. Button: "Stake Yes or No" while staking is open, "Watch it settle" during the window, and "See result & claim" once it's over. The button title is cached too, so it is only as fresh as the client's last fetch.
- **Mini app.** One market, one card that changes by phase:
  - A status pill: staking open with time to the Cutoff, window running, waiting for settlement, the winner, or Tie / Unmatched / Expired.
  - The question, the live price and the start and end readings.
  - The split bar: each side's share and the pot, noting that winners split it minus the 2% creator fee.
  - **Staking:** amount chips (0.001 / 0.005 / 0.01 ETH) and two big Yes/No buttons, each showing "pays X ETH · N.NNx now". No selling, and payouts shrink if others join the same side before the Cutoff.
  - After the Cutoff, a note that staking has stopped; once the window ends, "Settle (anyone can)".
  - The result and the Claim button on the same card. Refunds (Tie, Unmatched, Expired) say "no fee taken", and the creator sees the fee they were paid.
  - There is no lobby, no list of other markets and no separate claims inbox.
- **Framing.** The market is framed as Yes / No, not Up / Down.
- **Opening a market.** A three-step form (asset, window, an opening stake of 0.002 / 0.005 / 0.01 ETH) plus a 1–99 split slider, then "Open for X ETH". "Share to feed" casts it.

Prototype (primary source, never merged): local branch `prototype/feed-market`, route `/prototype/feed-market?variant=ticket`. The repo has no remote, so the branch is local only.
