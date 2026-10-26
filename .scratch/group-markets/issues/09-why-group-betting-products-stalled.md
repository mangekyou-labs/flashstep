# Why group betting products stalled

Label: wayfinder:research
Type: research
Status: closed
Assignee: MrSufferer

## Question

Did products that let friends or groups bet on their own questions stall, and if so, why? And what does informal group betting already look like in Vietnamese Zalo and Facebook groups?

[How friend and group prediction markets fared](03-how-friend-and-group-prediction-markets-fared.md) found no traction data and no postmortem for any friend-group product, so "they tried and failed" is unproven either way.

Cover:

- Manifold private groups (soft-launched May 2023, a premium feature): are they still offered, how many groups, and why didn't they grow? Look for Manifold blog posts, changelogs and community markets about them.
- Frens (Friendly Labs), "frr - Predictions with friends", the Friend Markets iMessage app, Telegram and Discord group-betting bots, and older friend-bet apps (onchain or not). For each: is it still alive, store ratings and review themes, founder posts, shutdown notices, and any download or user figures.
- For each product that stalled or died, give its cause as one of: (a) groups stopped creating questions, (b) a separate app people forgot to open, (c) disputes between friends, (d) stakes too small to make money, (e) law or app-store bans, or another named cause. Mark each cause sourced or inferred.
- Informal group betting in Vietnam: how football betting groups on Zalo and Facebook run (who posts odds, how stakes are tracked, how results are settled, group sizes), using news reports of prosecutions. Treat this as evidence of demand and of how groups already settle results, not as a model to copy.

Required output: a table with one row per product, giving its status, its cause, and whether the live-in-Zalo design answers that cause. Apply this rule: if the main causes are (d) or (e), say the idea is capped at a hobby or portfolio piece. If they are (a), (b) or (c), name which part of the design answers each.

## Resolution

No friend-betting product has a published shutdown notice, postmortem or download figures. The only first-hand account is a Manifund update on a Telegram group-markets bot (about 1 market a day, 5-7 bets each). Best-supported causes are (a) groups not creating questions and (b) a separate app that gets forgotten; (c) disputes and (d) small stakes have no source, and (e) law is documented only for real-money products. Zalo football betting groups are operator-run (operator posts odds and takes a margin, members message bets, periodic cash settlement), which shows demand. Hobby-cap rule: the points-only test is not capped; any real-money version is capped by (e). (b) is only partly answered because the Mini App can't post into the group; (a) is the test's main metric. Most causes are inferred, and Manifold private groups' current status is unverified.

Findings: `.scratch/group-markets/research/09-why-group-betting-products-stalled.md` on local branch `research/why-group-betting-stalled` (no remote, no PR).
