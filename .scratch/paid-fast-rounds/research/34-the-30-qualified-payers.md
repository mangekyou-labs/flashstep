# The 30 qualified payers

Research for ticket 34. Not legal or investment advice. Date: 2026-10-26.

Labels: **sourced** (first-party API or page, read on the date above), **sourced (secondary)** (search snippet or aggregator), **inferred** (my reading), **unverified** (not confirmed; do not act on it without checking).

## Summary

The target of 30 is **not reached**. Honest counts:

| Bucket | Target | Verified | Short |
|---|---|---|---|
| Token teams with a qualifying Base pool | ~18 | 25 pools qualify; 0 are Vietnamese-headquartered; 0 have a verified named BD lead for Rounds | no VN/Asian-first list can be built |
| Base launchpads / communities (>= 5 qualifying tokens) | ~12 | 0 confirmed | 12 |
| Fallback VN trading-group admins / streamers | 10 | 6 channels with verified handle and subscriber count (3 with a named business contact) | 4; no Vietnamese streamers identified |

Key findings:

1. The bar (pool liquidity >= US$100k and 24h volume >= US$50k) is cleared by about 25 real-project tokens on Base. That is a thin market, and almost none have a Telegram contact or named BD person. Most only expose X plus Discord.
2. No Vietnamese-headquartered project with a qualifying Base pool was found. Asian links are weak: AXIS Robotics (Singapore entity, per DexScreener/site) and KOTAEMON (possible Japan link, unverified).
3. No Base launchpad is confirmed at 5 or more qualifying tokens. Virtuals is closest: 3 agent tokens plus the platform token qualify (4). Clanker returned 0 in a spam-dominated top 100, which is inconclusive. Pangea and Doppler were not counted.
4. The Vietnamese fallback list is the most actionable part: named business contacts exist for HC Capital, ThuanCapital, Crypto Family and AnhReview.
5. Inference: ticket 32's ladder (Telegram, then X, then partnership channel) works for about 8 of the 25 token teams today (those with a public Telegram), and the Vietnamese-first, Vietnamese-language framing has almost no token-team targets. The pilot should probably lead with Vietnamese trading groups and English-language token teams.

## 1. Method (sourced)

- Pool data: DexScreener `token-pairs/v1/base/<token>` and `latest/dex/pairs/base/<pair>`; GeckoTerminal `/networks/base/pools?sort=h24_volume_usd_desc` pages 1-10 and `trending_pools`. Figures are DexScreener unless noted. Date checked for every row: 2026-10-26.
- Bar: at least one Base pool with liquidity >= US$100,000 and 24h volume >= US$50,000.
- Launchpad lists: Virtuals API (`api.virtuals.io/api/virtuals`), Clanker API (`/api/tokens`, limit <= 20, sort by market cap).
- Contacts: t.me public pages (subscriber counts, channel descriptions), project sites, DexScreener-listed socials. Anything not on those pages is marked "not found".
- Not done: no DMs sent, no emails sent, no logins. Founder names only where a first-party page names them.

## 2. Token teams with a qualifying pool

Liquidity / 24h volume in US$. "Partnership channel" is what a first-party page shows; "not found" means I did not find one. Language is the language to use in outreach. Asia flag: VN = Vietnam, other = Asian link, no = none found.

| # | Project | Pool (DEX / quote) | Pool address | Liq | 24h vol | Founder / BD lead | Telegram | X | Partnership channel | Lang | Asia |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | AXIS Robotics (AXIS) | Uniswap / USDC | 0xc19d91d99afc0332e5013a569c9721cd9ecb51a14c851f7a189a140950a627fa | 2,469,624 | 15,872,933 | not found (entity: Anima Technology Pte. Ltd.) | none | @axisrobotics | Discord discord.gg/axisrobotics | EN | Singapore entity |
| 2 | Venice (VVV) | Aerodrome / WETH | 0xdeBAEbE5B2729f7D62072b2eA40472d78d2C1626 | 2,860,381 | 3,664,568 | not found | none | @AskVenice | Discord discord.gg/askvenice | EN | no |
| 3 | Citrea (CTR) | Aerodrome / USDC | 0x0ab02e160f0df68dc049B012c514857306960Eae | 657,271 | 904,638 | not found | none | @citrea_xyz | Discord | EN | no |
| 4 | USD.AI (CHIP) | Aerodrome / USDC | 0x7779415171077FA77568d9E1FB5C66E3ee03d9c2 | 373,477 | 579,320 | not found | none | @USDai_Official | not found | EN | no |
| 5 | Derive (DRV) | Aerodrome / USDC | 0xA75f386C129F0478d61D1692eE7cc71BEB468d92 | 1,184,991 | 680,433 | not found | none | @derivexyz | Discord | EN | no |
| 6 | Morpho (MORPHO) | Aerodrome / WETH | 0x3626a7c07CF4a7EdEF2eC5d5d4B25bc8ab2C03F2 | 1,200,213 | 575,600 | not found | none | @morpho | not found | EN | no |
| 7 | Velvet Capital (VELVET) | Aerodrome / USDC | 0x6b0F53cbD9272D8117e9535FE25371dedF39a1bE | 1,031,011 | 378,301 | not found | t.me/velvetcapital | @velvet_capital | Telegram | EN | no |
| 8 | Dolphin (POD) | Uniswap v4 / ETH | 0x7c84276e317f128b55bd270dbfba3ef94c84b984c124a1de7c4f72da90bfba45 | 3,854,743 | 348,711 | not found | t.me/dphnAI | @dphnAI | Telegram | EN | no |
| 9 | Horizen (ZEN) | Aerodrome / WETH | 0x0392B12a1cEb0cd13af5Ea448CF5586EA609852D | 2,189,352 | 313,190 | not found | none | @horizenglobal | not found | EN | no |
| 10 | KOTAEMON | Uniswap / ADS | 0x0b18DC8062F313cC141168ef0D4367b973C03139 | 609,459 | 298,791 | not found; link to Cinnamon AI unverified | none | none | none | EN/JP? | unverified |
| 11 | Folks Finance (FOLKS) | Aerodrome / USDC | 0x94a734bf60cDe88ab10a9951b17278a3CE129860 | 332,806 | 281,529 | not found | t.me/FolksfinanceOfficial | @FolksFinance | "Work With Us" Google Form on site | EN | no |
| 12 | Superform (UP) | Aerodrome / cbBTC | 0x37e1490f7f6F98d263f826E1244C7E7f128632F2 | 494,989 | 204,217 | not found | none | @Superformxyz | Discord | EN | no |
| 13 | Nockchain (NOCK) | Aerodrome / USDC | 0x85f1Aa3a70fEdd1C52705c15BAEd143e675CD626 | 1,084,663 | 180,810 | not found | t.me/nockchainproject | @nockchain | Telegram | EN | no |
| 14 | Mamo (MAMO) | Aerodrome / cbBTC | 0xE2B3aA806e56603a244bFc111c9474F7DeDD03db | 344,737 | 163,880 | not found | t.me/MamoAIbot (a bot, not a contact) | @Mamo_agent | not found | EN | no |
| 15 | Surplus | Uniswap v4 / WETH | 0xfc25fdd217e288d03a877f0b7d49e0bbe52b2288c88de929125062569fc7eb2a | 1,251,686 | 163,013 | not found | none | @AskSurplus | "Talk to sales" link on site; Discord | EN | no |
| 16 | B3 (B3) | Aerodrome / WETH | 0x4Cd38b038513Dc5A73FBa933dAfA39F7233c44FA | 676,013 | 160,178 | Site names Viktoriya Hying (COO), Daryl Xu (CEO), Sean Geng (CTO); no BD contact | none | @b3dotfun | not found | EN | no |
| 17 | Veranta (AVNT) | Aerodrome / USDC | 0xe30d5BF485F7476AC15884a28ffb3C9cEA635DCB | 680,160 | 140,939 | not found | none | @verantaxyz | Discord | EN | no |
| 18 | Toshi (TOSHI) | Uniswap / WETH | 0x4b0Aaf3EBb163dd45F663b38b6d93f6093EBC2d3 | 1,013,805 | 95,638 | not found | t.me/toshibase | @Toshi | admin@toshithecat.com (site footer) | EN | no |
| 19 | Keeta (KTA) | Aerodrome / WETH | 0xd9eDC75a3a797Ec92Ca370F19051BAbebfb2edEe | 3,799,217 | 154,328 | not found | none | @KeetaNetwork | Discord | EN | no |
| 20 | Edel Finance (EDEL) | Aerodrome / WETH | 0x566beE7EF7b39f29d150AB3be6b6242C17CC5A31 | 1,066,176 | 110,784 | not found | t.me/edelfinance | @edeldotfinance | Telegram | EN | no |
| 21 | Tibbir (TIBBIR) | Aerodrome / WETH | 0x361FE0318Ac98F15720021CB8924b727C3E57D6F | 177,090 | 127,428 | not found | none | @ribbita2012 | not found | EN | no |
| 22 | Delivery Guy (DGUY) | Uniswap / AMZNc | 0x4bE684f77419999AA3E1162D25D9aE6FF64C05a0 | 137,548 | 92,841 | not found | TG + X both @StonksDGUY (as listed) | @StonksDGUY | Telegram | EN | no |
| 23 | Debt Relief Bot (DRB) | Uniswap / WETH | 0x5116773e18A9C7bB03EBB961b38678E45E238923 | 1,153,350 | 85,873 | not found | t.me/DebtReliefBotPortal | not found | Telegram | EN | no |
| 24 | Rainbow (RNBW) | Uniswap v4 / USDC | 0xb8e3840b850cd5e2d8229e54a04c3a10b653d072870bbfb26847d237fc655a37 | 145,998 | 54,941 | not found | none | @rainbowdotme | not found | EN | no |
| 25 | OneFootball Club (OFC) | Aerodrome / USDC | 0x44b5D0d8ce8C643c7e217E92492621C4c0Ae3121 | 146,900 | 51,989 | not found | t.me/onefootballclub_official | @ofc_the_club | Telegram | EN | no |

Notes:
- 25 pools qualify; none has a named BD lead. Rows 16 (B3 founders) is the only one with named people, and those are executives, not partnerships contacts.
- Contact-ready by the ticket 32 ladder (public Telegram): rows 7, 8, 11, 13, 18, 20, 22, 23, 25 (9 projects). The rest start at X DM.
- Pools with no socials at all (DACITY, PLAY, EVMZONE) qualify on numbers but are anonymous; excluded.
- Excluded as a competitor: Limitless (LMTS), a prediction market; pool 0xbe4C36B9542610dF83Ca690C8b5BC53BbbC5d542 (128.8k / 208.7k).
- Failed the bar on 2026-10-26: BRETT, DEGEN, AIXBT, KEYCAT, WELL, BNKR, CLANKER, ZORA, HIGHER, BID, noice.
- Inference: the 24h volume is a single-day snapshot. Several rows (e.g. TOSHI, DRB, RNBW, OFC) sit close to the US$50k floor and could drop out within days. Re-check before outreach.

## 3. Base launchpads and communities (bar: >= 5 qualifying tokens)

Zero are confirmed. Near-misses and partial candidates:

| Candidate | Evidence | Count at the bar | Status | Contact |
|---|---|---|---|---|
| Virtuals Protocol | VIRTUAL pool Aerodrome/WETH 0x792f465e0434fB1028EA3BfeB05240CB839C4e04, liq 2,068,820, vol 2,483,533. Three agent tokens from the Virtuals API also qualify. | 4 (3 agents + platform token) | Below the bar of 5 | TG t.me/virtuals, X @virtuals_io |
| Clanker | Clanker API top 100 by market cap was dominated by impersonators; CLANKER token itself failed the bar. | 0 found | Inconclusive (API lookup by address needs a key) | not checked |
| Pangea | PANGEA pool Uniswap v4/ETH 0xfd3272623e21c9ef661119d582b4c13ec4a0243e6f7bc13452fe57bee9304a59, liq 151,162, vol 419,142 | unknown | Qualifying-token count not checked | X @LaunchOnPangea |
| Doppler (XDP) | Pool Uniswap/USDC 0x2dF380544B88AdB3ad0A94100dcC45fd705aAE2d, liq 1,787,748, vol 26,272,314 | unknown | Launch protocol; launched-token count not checked | not checked |
| Aerodrome (AERO) | Pool Aero/WETH 0xc85D5CB72d1aaD6f152A8decAd228AE4A59Ac9B3, liq 2,187,210, vol 5,052,638 | n/a | A DEX, not a launchpad; questionable fit | X @aerodromefi |

No Vietnamese or Asian Base launchpad or community was found. Inference: the "about 12 launchpads" target does not exist at the stated bar on Base today. Options for the main session: lower the token-count bar to 3, or count the token teams in section 2 as the real payer list.

## 4. Fallback: Vietnamese trading groups and admins

Subscriber counts read from t.me public pages on 2026-10-26.

| # | Group | Channel | Size | Contact | X | Lang | Status |
|---|---|---|---|---|---|---|---|
| 1 | ThuanCapital | t.me/ThuanCapital | 88,888 subs | Partnership "Hop tac": @AdobeDuc; email admin@thuancapital.com; founder @ThuanLam (all from channel description) | not checked | VN | Verified |
| 2 | HC Capital | t.me/HCCapital_Channel | 63,713 subs; chat t.me/HCCapital_Chat 20,391 members | Business contact @HC_Speedy (channel description) | not checked | VN | Verified |
| 3 | Upside (Coin98 Insights) | t.me/Coin98Insights | 25,750 subs; chat t.me/Coin98Insights_Chat 14,428 members | not found | gm_upside | VN | Channel verified, contact not found |
| 4 | Crypto Family | t.me/CryptoFamilyTrading | 11,915 subs; group t.me/CryptoFamilyVN 8,446 | @JpMorganCF | @CryptoFamilyVN | VN | Verified |
| 5 | AnhReview Capital | t.me/tradingfomo | 11,537 subs | Support @hotroARC, @HoangPhucARC | not checked | VN | Verified |
| 6 | VIET NAM CRYPTO CHANNEL | t.me/VietNamCrypto_Channel | 1,104 subs | not found | not checked | VN | Verified, small |

Seen but unverified or too small, not counted: HC Tradecoin chat (t.me/hctradecoin_chat, 15,626 members; its parent channel and contact not checked), Trading Crypto Vietnam (t.me/tradingcryptovn, 252), Crypto VietNam Official (t.me/cryptovnofficial, 144), CryptoFamily Ventures (t.me/CryptoFamilyVentures, 220 subs), AnhReviewFree (159 subs), CoinF (t.me/CoinF_Group, generic page), GFI (t.me/GFI_Official, generic page), FOMOnista (no handle found), Le Duy, MarginATM, Rich Kids Trading, INFI Network. HC Capital's admin handle was first seen in a search result and then confirmed on the channel description.

No Vietnamese streamers were identified. Count: 6 verified channels (5 with a named contact), 4 short of 10.

Caveat (inferred): trading groups are paid promoters, not token teams with a pool. They do not themselves meet the pool bar, so they would be a distribution or co-sell route, not a payer under ticket 30's definition. Whether they fit is a decision for the main session.

## 5. Gaps and unverified

- No VN/Asian-first token team verified. AXIS Robotics (Singapore entity) and KOTAEMON (possible Japan/VN link via Cinnamon AI) are unconfirmed.
- Founder or BD lead: not found for 24 of 25 token teams; the B3 executives are the only names, and those are from the site only.
- Partnership channels: many are Discord only; I did not join Discord servers.
- Telegram handles for rows with "none" may exist but are not listed on DexScreener or the site; I did not guess.
- Launchpad counts for Pangea, Doppler, Clanker are not established.
- TG for MAMO is a bot, not a team contact. DGUY lists the same handle for TG and X; unchecked.
- Volumes are one-day snapshots from 2026-10-26.
- X handles for ThuanCapital, HC Capital, AnhReview not checked.
- WebFetch returned 403 for medium.com and telemetr.io; project site fetches often did not show founders or partnership pages.

## 6. Sources

- DexScreener API (`api.dexscreener.com`): `token-pairs/v1/base/<addr>`, `tokens/v1/base/<addrs>`, `latest/dex/search`, `latest/dex/pairs/base/<pair>`. Read via curl on 2026-10-26.
- GeckoTerminal API (`api.geckoterminal.com/api/v2/networks/base/pools`, `trending_pools`), pages 1-10.
- Virtuals API `api.virtuals.io/api/virtuals`; Clanker API `clanker.world/api/tokens`.
- t.me public pages and `t.me/s/<channel>` previews, read 2026-10-26.
- Project sites and official X/Discord links as listed by DexScreener (axisrobotics, askvenice, toshithecat.com, b3.fun, folks.finance and others).
