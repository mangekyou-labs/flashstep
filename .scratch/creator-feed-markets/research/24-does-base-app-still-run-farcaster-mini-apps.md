# 24. Does Base App still run Farcaster mini apps

Researched 2026-10-25. Method: web search plus page fetches (docs.base.org served as
raw markdown where possible). Sources are labelled [P] primary (Base's own docs, site or
announcement), [S] second-hand (blogs, aggregators, search-engine summaries of primary
pages), or [I] inferred by me. Each claim below carries one of these labels.

## Summary and verdict

**Verdict: NO for the Farcaster spec, PARTIAL for reaching Base App users.** Base App
no longer honours the Farcaster mini-app spec. A Farcaster-spec mini app does not need
to be rebuilt to be opened there, but Base App treats it as a plain web app, and it
gets Base App listing and notifications only through Base.dev.

- Base announced on 2026-03-12 that Base App would end support for the Farcaster
  mini-app spec and Neynar-powered metadata and notifications on 2026-04-09 [P: Base
  Build post on X, x.com/buildonbase/status/2032126286542311778, whose existence and
  title ("We're Updating How Apps Work in the Base App") I saw in search results, but
  X returned HTTP 402 so I could not read its text; the content comes from S sources
  that quote it].
- After that date Base App treats every app as a standard web app with wallet
  connectivity, regardless of any Farcaster manifest [S: three independent summaries
  of the Base migration guide; the guide page itself could not be read, see Gaps].
- Farcaster clients (Warpcast and others) keep their own integrations; the manifest
  and embeds still matter there [S: Neynar statement of 2026-03-27 as quoted by
  Arcabot].
- The Builder Grant and Builder Codes do not require Base App distribution, a
  Farcaster app, or a mini app [P: docs.base.org/get-started/builders.md and
  docs.base.org/specifications/builder-codes/overview.md]. They require a Base
  Dashboard (Base.dev) project, a Builder Code, and a `dataSuffix` on transactions.
- Cost of a Farcaster-first v1 that skips Base App: mostly discovery (Base.dev
  leaderboards, Base App store, auto-attribution, wallet-address notifications), not
  grant eligibility. Details in section 4.

## 1. What was dropped, what replaced it, dates

| Item | Before | After 2026-04-09 | Label |
|---|---|---|---|
| Announcement | n/a | Posted 2026-03-12 by Base (@base.base.eth / @buildonbase) | [S] Arcabot timeline; [P] X post exists but unreadable |
| Mini-app spec in Base App | Farcaster mini-app spec | Base App treats all apps as standard web apps | [S] |
| Metadata and listing | `/.well-known/farcaster.json` manifest, Neynar metadata | App metadata on Base.dev projects (icon, tagline, description, screenshots). Already-registered apps were backfilled and need no re-registration | [S] |
| Notifications | FID and token based, Neynar webhooks | First-party Notifications API to wallet addresses, via Base.dev. Only delivered in Base App; users must have pinned the app and opted in; up to 1,000 addresses per send; 20 requests/min/IP; title max 30 chars, body max 200 | [S] |
| Auth and actions | Farcaster SDK (`signIn`, `sendToken`, `openUrl`, `openMiniApp`, `viewToken`, `viewProfile`) | Sign-In with Ethereum via wagmi, ERC-20 transfer via wagmi, `window.open`, `base.app/coin` deeplinks. Base App no longer invokes the old SDK methods | [S] |
| Discovery | Farcaster feed and search | Base.dev metadata, Builder Codes, Base.dev Leaderboards (first one covers mini apps in Base App) | [S] |
| Tooling | MiniKit, OnchainKit | Base recommends moving off these wrappers to wagmi/viem | [S] |
| Migration helper | n/a | An agent "Migration Skill": `npx skills add base/skills` | [S] (listed on mcpservers.org, which returned 403 to me) |

Still true on 2026-10-25? I found no evidence of a reversal. The search summaries are
all consistent that the change took effect and nothing newer contradicts it, but
absence of a reversal in search results is [I], not proof. One more flag: on 2026-10-25
the Base docs URL for the guide (docs.base.org/apps/guides/migrate-to-standard-web-app)
returns the generic "Build financial products on Base" overview page, and the
docs.base.org/llms.txt index (48 KB) has no mini-app, MiniKit, Farcaster or
notifications entries [P]. [I] The docs were reorganised toward finance-focused
content and the mini-app guides were removed or moved. A Wayback snapshot of the guide
exists (2026-06-10) but my fetcher blocks web.archive.org.

## 2. Can a Farcaster-spec mini app still reach Base App users?

- **Yes, as a web app.** Base App opens apps in an in-app browser with an injected
  wallet, and listings come from Base Dashboard metadata, not the Farcaster manifest
  [S: a GitHub PR in Borodutch/veydrift surfaced in search, plus the summaries above].
- **What stops working:** Farcaster SDK calls (`sdk.actions.*`, Quick Auth / `signIn`),
  Farcaster-embed rendering, FID-based identity and Neynar notifications [S]. An app
  that hard-depends on them "will not function properly" in Base App [S, search
  summary].
- **What it takes** [S, from the migration guide as summarised]:
  1. Register the project on Base Dashboard (base.dev) and fill in metadata.
  2. Replace Farcaster SDK auth and actions with wagmi/viem and SIWE; use a standard
     wallet connector.
  3. Optional: use the Base Notifications API for wallet-address notifications.
  4. Keep the Farcaster manifest and embed tags for Farcaster clients; Base App
     ignores them.
- [I] A single web app can serve both surfaces: detect the Farcaster context and use
  the Farcaster SDK there; fall back to a wallet connector and SIWE elsewhere. I found
  no first-party doc describing this dual-mode pattern, so treat it as design
  inference. It matches Arcabot's note that "a standard web app with wallet
  connectivity can serve Base App without Farcaster-specific code" [S].
- Trust and identity are now two separate systems: Farcaster (FID, social graph,
  manifest, client moderation) and Base (wallet address, Base.dev registration, pinned
  state) with no shared identity or preferences [S].

## 3. Do the Builder Grant and Builder Codes need Base App distribution?

**No, on the pages I could read.**

| Programme | Requirement found | Mentions Base App or Farcaster as a requirement? | Label |
|---|---|---|---|
| Builder Grant Program | "The first step to be eligible for grants is to integrate Builder Codes." Up to $5,000 plus GTM and product support. Focus areas include **prediction markets**, token launchpads, DeFi 2.0, agents, new asset creation, consumer apps focused on transaction growth. Apply via a form for the next cohort. "The Base team provides grants very selectively." | No | [P] docs.base.org/get-started/builders.md |
| Builder Codes | Register a project on Base Dashboard to get a code (ERC-721 NFT collection; ERC-8021 calldata suffix). Works with EOAs and smart wallets. No contract changes needed. | No | [P] docs.base.org/specifications/builder-codes/overview.md and for-app-developers |
| Attribution outside Base App | Base App auto-appends your code to transactions made in your app within Base App. Users on the web or other clients need your own `dataSuffix` integration (viem 2.45.0+; wagmi needs it per write call) | Base App is optional; the suffix is the portable route | [P] for-app-developers (via fetch summary) |
| Rewards | "Unlocking rewards as the program expands"; "potential future rewards"; no criteria, amounts or timeline given | n/a | [P] |
| Visibility | "Apps with Builder Codes can show up in discovery surfaces like App Leaderboards, Base App store, and ecosystem spotlights." | Benefit, not a requirement | [P] overview.md |

[I] Prediction markets are an explicitly listed grant focus area, so a creator-market
app fits the programme, but eligibility is a form application judged by the Base team,
so the docs do not guarantee anything. The "Regional Amplification" support applies to
anyone "actively building on Base with traction" [P]. A Farcaster-only app on Base
chain with a registered Builder Code and `dataSuffix` on its transactions is, by the
docs, accepted. I found no statement that a Farcaster-only app is disfavoured.

## 4. What a Farcaster-first v1 loses by skipping Base App

- **Lost [P/S]:** Base App store and Base.dev leaderboard placement (Builder Codes
  list these as discovery surfaces); Base App wallet-address notifications; free
  auto-attribution of Base App users' transactions; Base App as an audience (a
  Coinbase-wallet-linked consumer base; I found no active-user figure, so size is
  unverified).
- **Not lost [P]:** grant eligibility, Builder Code registration, rewards eligibility
  (all tied to Base Dashboard registration and onchain suffix, not to the client).
  Registering the project on Base Dashboard is cheap and needed for the code anyway.
- **Not lost [S]:** Farcaster distribution, since Warpcast and others keep the spec.
- **Net [I]:** Skipping Base App costs reach, not funding. It cannot be zero-cost to
  add later, because auth and actions need the wagmi/SIWE path. Building the wallet
  path first (wagmi, SIWE, `dataSuffix` on every write) and treating Farcaster SDK
  features as progressive enhancement keeps Base App open as a later add.
- Link to ticket 19: its claim that "in the feed" now effectively means Farcaster
  clients [S] holds up. Base App still has a feed-like surface, but through Base.dev
  listing, not through embeds.

## Gaps and unverified

- The Base migration guide itself could not be read (the live URL now shows an
  unrelated overview page; X post returned 402; Wayback is blocked for my fetcher).
  All details in section 1 come from search-engine summaries and the Arcabot piece
  quoting it. They are mutually consistent but not first-hand.
- The Base.dev listing process (review, criteria, any fee) is not documented in
  anything I read.
- Whether Base App users can still open Farcaster-embed links at all, as opposed to
  just rendering apps as web apps, is not confirmed.
- Whether anything changed after 2026-06 (new mini-app programme, rebrand, or
  reversal) is unverified. The finance-focused docs reorganisation hints that Base's
  priorities moved [I], nothing more.
- Grant outcomes and acceptance rates for Farcaster-only apps: no data. The grant
  page is silent on client surface.
- Base App active-user numbers: not found.

## Sources

- [P] https://docs.base.org/get-started/builders.md (grant programme, Builder Codes as first step)
- [P] https://docs.base.org/specifications/builder-codes/overview.md (what Builder Codes are, benefits, FAQ)
- [P] https://docs.base.org/specifications/builder-codes/for-app-developers (Base App auto-append, dataSuffix elsewhere)
- [P] https://docs.base.org/llms.txt (index has no mini-app pages as of 2026-10-25)
- [P, unreadable] https://x.com/buildonbase/status/2032126286542311778 (announcement, HTTP 402)
- [P, now redirected to an unrelated overview] https://docs.base.org/apps/guides/migrate-to-standard-web-app
- [S] https://paragraph.com/@arcabot/base-and-farcaster-split-the-mini-app-stack (timeline, API limits, what stays compatible)
- [S] search summaries of the Base guide and https://mcpservers.org/agent-skills/base/skills/convert-farcaster-miniapp-to-app (403)
- [S] https://github.com/Borodutch/veydrift/pull/1903 (Base App opens apps as web apps; seen in search results only)
