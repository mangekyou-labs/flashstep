# Legal path for real-money creator markets

Label: wayfinder:research
Type: research
Status: closed

## Question

How can a solo developer living in Vietnam ship a real-money, permissionless prediction market on Base without personal criminal or civil risk?

Start from [Vietnam law for points and real-money group markets](../../group-markets/issues/02-vietnam-law-for-points-and-real-money-group-markets.md). Cover:

- Whether writing and deploying immutable contracts, versus running the frontend, counts as operating gambling under Vietnamese law; any cases.
- Common structures: a foreign entity (BVI, Panama, Cayman, Delaware), frontend geoblocking, a frontend run by someone else, and what each costs.
- How Limitless, Opinion and Melee are structured, and how Polymarket's 2022 CFTC case and later return bear on a small builder.
- Whether creators who seed markets take on legal risk themselves.

Required output: the cheapest structure that keeps the developer outside the likely liability, its cost and setup time, and what a lawyer must confirm. Mark each claim sourced or inferred.

## Resolution

Cheapest structure: deploy immutable contracts with no owner, admin keys or developer fee; a separate foreign operator (e.g. a Panama foundation, about $2-5k, about 1 week) runs the frontend and geoblocks Vietnam, the US and sanctioned regions; the developer holds no shares, role, keys or fees in it; the developer's own product stays points/testnet only. Total about $2-5k plus legal review, 2-4 weeks. Risk is reduced, not removed: Vietnam Penal Code Art. 6 can reach acts abroad by a citizen or resident. Lawyer must confirm: (1) whether a code-only deployer with no frontend or fees is an accomplice under Art. 321/322; (2) whether citizenship or residence reaches the developer despite an offshore operator, and whether they may hold any role in it; (3) whether creators and liquidity seeders carry organiser liability, and residual CFTC/DOJ risk with a US geoblock. Only the CFTC 2022 release and Limitless terms are first-party; the rest is secondary or vendor estimates. No Vietnamese case against a pure code author found, but the search was shallow and English-only. Opinion's and Melee's entities and Panama gambling law were not checked.

Details and sources: [research/20-legal-path-for-real-money-creator-markets.md](../research/20-legal-path-for-real-money-creator-markets.md)
