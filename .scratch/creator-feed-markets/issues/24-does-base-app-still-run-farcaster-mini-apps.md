# Does Base App still run Farcaster mini apps

Label: wayfinder:research
Type: research
Status: closed
Blocked by: none
Assignee: MrSufferer

## Question

Does Base App still open and render Farcaster mini-app embeds as of late 2026? [Who already runs creator markets in the feed](19-who-already-runs-creator-markets-in-the-feed.md) found a second-hand report that support was dropped on 2026-04-09.

Cover:

- First-party Base or Coinbase announcements, docs and changelogs on mini-app support: what was dropped, what replaced it, and the dates.
- Whether a mini app built to the Farcaster spec can still reach Base App users, and what it would take (a different manifest, Base-specific SDK, an app listing).
- Whether the Base Builder Grant or Builder Codes require Base App distribution, or accept a Farcaster-only app.

Required output: a yes/no/partial answer with sources, and what a Farcaster-first v1 would lose by skipping Base App. Mark each claim sourced or inferred.

## Resolution

**Partial, leaning no for the spec.** Base announced on 2026-03-12 that Base App would end support for the Farcaster mini-app spec and Neynar-powered metadata and notifications on 2026-04-09. Base App now treats every app as a standard web app with an injected wallet: `farcaster.json` is replaced by Base.dev project metadata, Farcaster SDK auth by wagmi/viem and Sign-In with Ethereum, and FID notifications by wallet-address notifications through a Base.dev API. Farcaster clients such as Warpcast keep their own integrations. A Farcaster-spec app still opens in Base App as a plain web app, but needs a wallet connector, SIWE and a Base.dev registration to behave well there. Inferred, not documented: one web app can serve both surfaces by using the Farcaster SDK in Farcaster and wagmi/SIWE elsewhere.

A Farcaster-first v1 loses Base App store and leaderboard placement, wallet-address notifications and automatic Builder Code attribution of Base App users' transactions, plus Base App's audience (no user numbers found). It does not lose grant eligibility, Builder Code registration or Farcaster distribution. The Base Builder Grant and Builder Codes do not require Base App distribution (Base docs: Builder Codes integration is the first step; store and leaderboard placement are benefits, not requirements). Adding Base App later is cheap only if v1 uses wagmi/SIWE for wallet and auth from the start.

Unverified: Base's migration guide itself couldn't be read (the live URL returns an unrelated page, the X announcement returned 402), so the details rest on a second-hand write-up and search summaries that agree. The Base.dev listing process, whether Base App users can open Farcaster-embed links, any post-June reversal, and grant outcomes for Farcaster-only apps are unconfirmed.

Details and sources: [research/24-does-base-app-still-run-farcaster-mini-apps.md](../research/24-does-base-app-still-run-farcaster-mini-apps.md)
