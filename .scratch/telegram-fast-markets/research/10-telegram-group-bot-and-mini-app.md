# Research 10: What Telegram lets a group bot and Mini App do

Researched 2026-10-24. Sources fetched that day. Where a page is undated, it is marked "undated".
Bot API version seen: 10.3 (dated August 24, 2026), per https://core.telegram.org/bots/api.

## Short answer

- A group bot can do everything the chat flow needs: read `/predict 10 yes`, post and edit messages, show inline buttons, and check a named user's membership. It cannot list all members.
- A Mini App opened from a group by direct link learns the user and a `chat_instance` ID, not the group's chat ID. The bot has to supply the group ID some other way.
- No primary Telegram document bans or permits gambling or betting. A free points game is very likely fine. Real-money betting is unaddressed in the text, and enforcement is case by case (secondary sources).
- Crypto rules bite only when a Mini App is involved: TON only, TON Connect only. A plain bot with no Mini App is exempt.
- There is no pre-launch review and no entity requirement in the terms.

## 1. Bot capabilities in groups

- **Privacy mode** (https://core.telegram.org/bots/features, https://core.telegram.org/bots/faq; both undated). On by default.
  - With privacy mode on, the bot receives: commands addressed to it (`/cmd@bot`), general commands like `/start` only if it was the last bot to post in the group, messages sent via the bot, and replies to the bot's messages.
  - Group admins and bots with privacy mode off receive all messages except those from other bots.
  - All bots receive service messages. No bot ever sees messages from other bots.
  - Changing the mode requires re-adding the bot to the group.
  - **Implication:** `/predict 10 yes` works under privacy mode if sent as a command (`/predict@botname 10 yes`; Telegram clients autocomplete the suffix in groups with several bots). Plain-text parsing needs privacy mode off or admin status.
- **Commands.** Up to 32 characters, Latin letters, digits, underscores. The update does not say which scope the command was sent under. Verify authorization server-side.
- **Inline buttons.** Callback, URL, web_app, switch-inline, payment and other types. Pressing a callback button sends nothing to the chat. The docs recommend editing the keyboard in place rather than sending and deleting messages.
- **Editing.** `editMessageText` takes 1 to 4096 characters. A bot can edit its own messages, including ones with an inline keyboard (https://core.telegram.org/bots/api). A live "pot and odds" message can be edited in place.
- **Reading who is in the group.**
  - `getChatMember(chat_id, user_id)` checks one user. It is "only guaranteed to work for other users if the bot is an administrator in the chat".
  - `getChatMemberCount` returns a number only.
  - `getChatAdministrators` returns admins only.
  - The `chat_member` update (join/leave/status changes) requires the bot to be an admin and `"chat_member"` listed in `allowed_updates`.
  - I found no method in the parts of the API page I read that lists all members. About 180k characters of the API page were not read, so this is not fully ruled out. Confidence is moderate to high that none exists.
  - **Implication:** the bot can only know people who spoke, pressed a button, or joined while it was an admin.
- **Rate limits** (https://core.telegram.org/bots/faq, undated).
  - About 1 message per second per chat (short bursts allowed, then HTTP 429).
  - 20 messages per minute per group.
  - About 30 messages per second for bulk sends.
  - Paid broadcast (1000 per second at 0.1 Stars per message) needs 100,000 Stars and 100,000 monthly active users, so it is not relevant to us.
  - **Implication:** the 20 per minute group cap constrains a minutes-long market. Edit one message instead of posting many. Callback answers and edits count against API limits. I could not confirm whether edits count toward the 20 per minute group figure (uncertain).
- **Other.** `sendDice` exists. The default Bot API `getUpdates` queue holds updates for 24 hours.

## 2. Mini App capabilities

Source: https://core.telegram.org/bots/webapps (undated; about 13k characters at the end unread) and https://core.telegram.org/api/links.

- **Launch methods:** main Mini App, keyboard button, inline button (`web_app`), menu button, inline mode, direct link, attachment menu.
- **Direct link:** `t.me/<bot>/<short_name>?startapp=<param>&mode=compact|fullscreen`, and `t.me/<bot>?startapp=<param>` for the main app. The docs say it "can be launched from a direct link in any chat". A link posted in a group is therefore a way to open the app from that group.
- **Identifying the user.** `initData` carries `user`, `auth_date`, `hash` and `signature`. Validate server-side with an HMAC derived from the bot token, or with Telegram's Ed25519 public key. Never trust `initDataUnsafe`.
- **Identifying the group.**
  - For direct-link launches, `chat_type` (`sender`, `private`, `group`, `supergroup`, `channel`) and `chat_instance` are returned. `chat_instance` is a "global identifier uniquely corresponding to the chat", not the chat ID.
  - The `chat` object (with `id`) is documented only for attachment-menu launches and join requests.
  - Keyboard-button and inline-mode launches give an empty `initDataUnsafe`.
  - **Practical pattern:** have the bot post a button with a `startapp` parameter containing a market ID. The server maps market ID to group. Or map `chat_instance` to group on first use. The inline `web_app` button in groups is not confirmed by the docs (uncertain). A direct link is the documented route.
  - `start_param` is free-form.
  - `startgroup` links (`t.me/<bot>?startgroup=<param>`) add the bot to a group, with up to 64 base64url characters of parameter.
- **Payments.** Stars invoices through `openInvoice`, plus third-party providers. Digital goods and services in a Mini App must use Stars (Terms for bot developers section 6.2, https://telegram.org/tos/bot-developers). Not needed for points.
- **Wallet connection.** TON Connect is the only permitted protocol (see section 3). https://docs.ton.org/ecosystem/ton-connect/overview (undated).
- **Other.** `shareMessage` / `savePreparedInlineMessage` post from the Mini App into a chat the user picks. `sendData` is limited to 4096 bytes and only works from keyboard-button launches.
- **Recent change:** Bot API 10.2 blocks Mini App methods from origins other than the Mini App domain. It is enabled for all Mini Apps on July 20, 2026, with an opt-out in @BotFather. Check iframes and CDNs against this.

## 3. Terms and rules on gambling, betting and crypto

- **Gambling and betting.** The word does not appear in:
  - https://telegram.org/tos (undated). The prohibitions are spam/scam, promoting violence, illegal pornography, and "activities that are recognized as illegal in the majority of countries".
  - https://telegram.org/tos/bot-developers (undated). Closest is section 5.2(h), prohibiting "illegal, pirated, regulated or questionable goods and services".
  - https://telegram.org/tos/stars (undated). Stars may be used for "digital goods and services from bots and mini apps", paid media, donations and gifts. They may not be sold, withdrawn or transferred outside the stated uses.
  - https://core.telegram.org/bots/blockchain-guidelines (undated).
  - https://telegram.org/tos/mini-apps appears to be a different document and has nothing relevant.
  - **Reading:** a free-points game has no goods, no payment and no asset, so it sits outside every restriction found. "Regulated" services (5.2(h)) is the clause that real-money betting could trigger. That is interpretation, not text.
- **Crypto in Mini Apps** (Terms for bot developers section 7 and the blockchain guidelines).
  - A Mini App with crypto functionality must use TON exclusively for tokens and blockchain assets.
  - It may only interface with wallets connected through the TON Connect SDK. Other wallet protocols are allowed only for bridging.
  - It may not promote non-TON assets or wallets, and may not fork TON Connect.
  - Deadlines: assets issued on or after January 21, 2025 must comply. Existing apps had to migrate by February 21, 2025.
  - **Scope:** "these rules only apply to Mini Apps and their bots… Regular Telegram bots that do not have a Mini App component are exempt."
  - **Implication:** an onchain Base testnet version with a Mini App would break the TON-only rule if it handles Base assets. A points-only offchain Mini App triggers none of it. This closes the "onchain Base testnet" option for the Mini App, but a Base-only bot with no Mini App is exempt (uncertain whether "their bots" covers a bot that links out to a web app).
- **Review and listing.**
  - No pre-launch review appears in the bot developer terms. Telegram "chooses which [apps] to feature at its sole discretion, based on popularity" (section 8.2.1). A secondary source says there is no upfront vetting (merge.rocks, not authoritative).
  - Verified status is assigned at Telegram's "sole discretion" (section 2).
  - I found no official App Center eligibility criteria (uncertain).
- **Enforcement.** Violations can lead to a temporary or permanent ban from the Bot Platform or Telegram (sections 5.4 and 10). Telegram may discontinue any bot or the platform at any time (10.1).

## 4. Costs and requirements

- **Hosting.** Not specified by Telegram. A Mini App needs an HTTPS URL registered with @BotFather. A bot needs a server with a webhook or long polling. Free tier hosting is enough for a test (my judgement).
- **Entity and verification.** The terms I read contain no requirement to register a business. Developers are "independent parties" (section 2.1).
- **Fees.** Bot API access is free. Stars purchases carry a 15% fee withheld by Telegram, and 1 Star pays developers about 0.013 USD (6.2.4 and 6.2.6). Payouts go through Fragment, with a hold of up to 21 days. None applies to a points-only product.
- **User data.** Section 4 requires encryption at rest and bans compiling large datasets. A Privacy Policy button is shown on Mini Apps.
- **Taxes and law.** The developer is "solely responsible" for taxes (6.4). A legal guide says Telegram is only a platform provider and the project team needs licences for regulated activity (https://aurum.law/newsroom/Telegram-Mini-App-Legal-Checklist-in-2025, secondary).

## 5. Examples and bans

- **TG.Casino Portal.** Reported banned. GamblingNews, published 2025-02-20 (secondary): "This bot can't be displayed because it violated Telegram's Terms of Service." Telegram gave no public statement. The article does not say which clause or whether other casinos stayed up. A search summary says many other casino bots remain active and enforcement is selective. Those were secondary sources (bonus.com, igaminghub).
- **Polycule.** A Telegram bot for trading on Polymarket with chat commands and group trade broadcasting (https://polymark.et/product/polycule, secondary).
- **Predicton / "Predict with Polymarket".** A TON Mini App with a TON wallet, USDT, Polymarket liquidity and STON.fi routing. Reported live around June 24 to 25, 2026 (https://cryptoadventure.com/polymarket-powered-predicton-brings-prediction-markets-into-telegram-on-ton/, secondary). It shows a prediction-market Mini App exists on the platform with a TON wallet.
- **Others** listed in a directory: okbet, Predictify, PolyFocus, PolyBot (secondary).
- **Bans.** I found no report of a prediction-market bot being banned by Telegram. This is absence of evidence from a limited search.

## Gaps

- Exact API text for `getChatMember` and friends was read from partial page fetches.
- Whether `web_app` inline buttons work in groups is not stated in what I read.
- No primary statement on gambling or prediction markets. Treat "free points is allowed" as a reasonable inference, not a ruling.
- App Center and featuring criteria are not documented in what I found.

---

# Addendum (2026-10-24): onchain on Base, sponsored gas, no-value stakes

Ticket moved to .scratch/base-grant-markets/. Destination is now onchain on Base mainnet. Source for all of section 7 below: https://telegram.org/tos/bot-developers (undated), read via a summarising fetch, so quotes are excerpts.

## A. The TON-only rule, exact scope

- Section 7 intro: applies to "all Mini Apps which implement cryptocurrency functionality, either within the Mini App itself or within its connected bot".
- 7.1: new tokens or assets must be created and distributed exclusively on TON.
- 7.2: "Any Mini App that utilizes functionality related to cryptocurrency wallets must only interface with wallets" connected through TON Connect. Other wallet protocols only for bridging assets to TON (blockchain guidelines, https://core.telegram.org/bots/blockchain-guidelines).
- 7.3: multichain wallet Mini Apps (custodial or not) may manage other-chain assets inside their own interface.
- 7.4: Mini Apps may not "directly or indirectly" promote non-TON cryptoassets. A summary reading says this includes linking to platforms that promote them (uncertain, paraphrase).
- Blockchain guidelines: "Regular Telegram bots that do not have a Mini App component are exempt."

## B. Can an EVM / Base wallet run inside a Mini App?

- **Technically, partly.**
  - Privy documents Mini App use: seamless Telegram login, and `embeddedWallets.ethereum.createOnLogin` works in "a Telegram mini app". Domains `https://web.telegram.org` must be allowed, and `.xyz` domains are not supported for Telegram auth (https://docs.privy.io/recipes/react/seamless-telegram, https://docs.privy.io/recipes/wallets/user-and-server-signers; found via search summaries, pages not fetched directly).
  - Passkey-based wallets, including Coinbase Smart Wallet, are reported to fail in Telegram's webview with NotAllowedError (FIDO Alliance dev thread, secondary: https://groups.google.com/a/fidoalliance.org/g/fido-dev/c/wRXe-oU5MZ4). No Coinbase or Telegram source confirms or denies. Treat as likely broken, needs a test.
  - External wallet deep links (RainbowKit) are reported broken in the webview (https://github.com/rainbow-me/rainbowkit/issues/2241, secondary).
  - I did not verify Dynamic.
- **By the rules, a Base wallet inside a Mini App is a conflict.** An embedded EVM wallet is "functionality related to cryptocurrency wallets", and 7.2 says wallets must be connected through TON Connect. The only carve-out is 7.3 (a Mini App that is itself a multichain wallet) and bridging. An app-owned embedded wallet is arguably neither. This is my reading; the text does not address embedded or smart wallets (uncertain).
- Paymaster / sponsored gas is not mentioned in any Telegram document.

## C. Does a free-to-play game with no-value tokens count as "crypto functionality"?

- The text of section 7 does not define "cryptocurrency functionality" and has no carve-out for tokens without cash value. Nothing says points or valueless tokens are exempt (uncertain, no primary source either way).
- Reading: Mini Apps that create or distribute onchain tokens (7.1) or touch wallets (7.2) are inside the rule. Onchain stakes on Base are "tokens or blockchain assets" on a non-TON chain even if valueless, so 7.1 is the likeliest hit. A purely offchain points ledger is not touched at all.
- No example found of Telegram enforcing section 7 against a valueless-token app.

## D. Plain bot plus web link (no Mini App)

- The blockchain guidelines exempt "regular bots that do not have a Mini App component". The section 7 text refers to bots only as the "connected bot" of a Mini App.
- A bot that posts a normal URL (opened in the external browser or in Telegram's in-app browser) to a Base dapp, with no Mini App registered or launched, is not a Mini App on any definition I found. The terms do not define "Mini App" separately (section 1 to 2), and the boundary is unspecified.
- Risks:
  - Telegram's in-app browser is not a Mini App, but I found no official statement that the exemption covers link-outs.
  - If the same bot also has a registered Mini App with crypto features, section 7 can reach it through "connected bot".
  - Section 5.2(h) ("regulated or questionable services") and the ban powers (5.4, 10) still apply to any bot.
  - Passkey wallets work better in the external browser (opening it via Mini App `openLink` or a plain URL), per the FIDO thread (secondary).
- This resolves my earlier flag only partly: the exemption is documented, but whether a bot that is only a front door to a Base dapp is safe is untested and unratified by Telegram.
- Group context is unchanged: the bot can read commands and post, and the web link would carry a market ID (start parameter or URL query) since a plain URL gives no Telegram user identity. User binding would need Telegram Login or a signed deep link (not researched here).
