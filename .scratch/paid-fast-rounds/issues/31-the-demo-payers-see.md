# The demo payers see

Label: wayfinder:prototype
Type: prototype
Status: closed
Blocked by: 30
Assignee: MrSufferer

## Question

What is the cheapest demo that makes a payer say yes to a pilot? Build it rough (a clickable Round loop, a recorded video, or a one-page pitch with a live mock) and link it here. It is a sales asset, not the product.

## Resolution

Prototyped with the user on 2026-10-26. The demo is the **player view**: a single HTML page showing one live, payer-branded Round market the way a holder sees it, in Kalshi's design language (light, cents pricing, Yes/Up green and No/Down red, a chance headline, a price chart with a dashed reference line, a trade panel with Stake cap and "To win", a recent-Rounds table) with motion per emil-design-eng. Rebrand per prospect with `?brand=<TICKER>`. It runs on a mock price feed with simplified AMM math; it's a sales asset, not the product.

The first toy-styled version was rejected as looking like a toy. The pitch one-pager and payer dashboard variants were built but not chosen. A screen recording for cold DMs was not settled; it is left to [Run the outreach](../../run-the-outreach/task.md): record one if cold DMs get no clicks.

Asset: `.scratch/paid-fast-rounds/prototype/PROTOTYPE-demo.html` (`?v=player`), captured on the local branch `prototype/demo-payers-see` (commit b8318ff; no remote, never merged).
