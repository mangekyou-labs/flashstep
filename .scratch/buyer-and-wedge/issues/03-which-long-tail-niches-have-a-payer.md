# Which long-tail niches have a payer

Label: wayfinder:research
Type: research
Status: resolved

## Question

This is candidate C. Which question niches do Polymarket and Kalshi serve thinly (low liquidity, wide spreads, few markets, or none), where someone outside the traders already pays to get forecasts or price discovery?

Cover:

- Polymarket and Kalshi liquidity by category: where markets exist but stay thin, and where they don't exist (for example crypto protocol metrics, scientific replication, software release dates, sports below the top leagues, local events, corporate forecasting). Use published data, dashboards, or APIs.
- For each candidate niche, a payer who pays today for the same information by other means: consultancies, forecasting platforms (Metaculus, Good Judgment), internal corporate prediction markets, research funders, insurers, hedgers. Name the price where it is published.
- Regulatory blockers to a crypto-native market in that niche, at summary level.

Rank up to 5 niches by: a named payer who paid in the last 12 months, incumbents thin, and no existing community access needed to reach the payer. Do not pick one; the grilling ticket does.

## Answer

Ranked niches (not a pick):

1. Research-funding and science-policy outcomes (NIH/NSF budgets). Payer: Coefficient Giving's Abundance & Growth Fund commissioned Metaculus Pro Forecasters (Sep 2025, price unpublished). No matching Polymarket or Kalshi markets found.
2. AI capability and release-timing questions. Funders: Coefficient Giving to FRI ($1.07M LEAP panel, Oct 2024; $10.08M general support, Mar 2025). Metaculus AI benchmark, Spring 2026, $58K prize pool. Polymarket and Kalshi AI sub-markets are thin (liquidity $3-7K; one Kalshi monthly market at $13 24h volume).
3. Organisational and corporate forecasting. Good Judgment FutureFirst about $20K/year (dated); Bridgewater x Metaculus 2026, $30K prize pool. Cultivate Labs dropped prediction markets in 2022 for opinion pools.
4. Niche-risk hedging. A LA restaurant group's $60K Kalshi hedge (Oct 2026). Kalshi already serves weather, so this likely trips kill rule (ii).
5. Crypto protocol metrics and token launches. Launch markets are deep; protocol-metric markets are tiny (Aave TVL: $3.5K volume). No outside payer found.

- Only the Bridgewater and Metaculus AI benchmark payments fall inside the last 12 months, and neither is a payment for information or liquidity. The funder payments are 13+ months old, so kill rule (i) is not cleanly passed by any niche.
- Both incumbents are thin everywhere past headline markets. In my API sample over 88% of Kalshi markets had zero 24h volume in every category (76% for weather). Neither venue publishes depth data.
- Regulation: the CFTC issued an interim final rule on 2026-10-09. Polymarket US is CFTC-designated; the on-chain venue is closed to US IPs; states are litigating. Hedging-style niches (3, 4) fit the CFTC "hedging utility" test better than information-only niches (1, 2).

Caveats: Metaculus and Good Judgment prices are unpublished, and their pages returned 403. The liquidity samples are partial and overstate depth. Several payer figures come from secondary sources. See the Unverified section in the findings file.

Findings: docs/research/long-tail-niches.md on branch research/long-tail-niches, commit c30326e. Branch is local; no origin remote.
