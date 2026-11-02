# Independent ETHSKILLS QA — flashstep #15

Reviewed clean commit `ff6a588e321b3ab2eaa59e5151329c2ea0a1d77a` in `/private/tmp/flashstep-qa-15` on 2026-11-02. Applied the supplied qa and crops skill files in full. Read AGENTS.md, GLOSSARY.md, ADR 0004, handover, local-page, threshold-page, proof-sharing, outage-refunds, payer-deploy and settle-bot documentation, and relevant frontend/config/contracts. No source changes, deploy, verification, account operations or real wallet secrets.

**Pilot verdict: not ready for a real-money pilot without the production wallet/RPC fixes and release verification below.** Local configuration editing/export is not proof of safe production onboarding. No claim of a new exploitable contract bug is made by this review.

## Concrete findings

### High — local-only burner protection is bypassed for a real-money Base Campaign
- Files: `packages/nextjs/services/web3/wagmiConnectors.tsx:16-27`; `packages/nextjs/services/web3/wagmiConfig.tsx:11`; `packages/nextjs/scaffold.config.ts:20`.
- `showBurnerWallet` examines foundry-only `targetNetworks`, while actual wagmi chains independently include Base, Base Sepolia and Ethereum. A runtime brand edit to Base leaves Burner Wallet available. The comment explicitly preserves this behavior. The installed burner package documents operation on Base/mainnet and browser-persisted wallet storage. A player can select an unsafe browser wallet for funds without a backup/recovery explanation; clearing browser state or compromised page JavaScript can affect access to real funds.
- Evidence: actual disconnected browser wallet modal lists Burner Wallet. Live Base switching/signing was not executed.
- Fix: disable burner in the production handover build (keep it only in an explicit development mode), or enforce local-only connector operation using the effective connected chain. Test a Base brand and confirm the burner cannot be used there.

### Medium — production handover has no RPC provisioning path and retains public/shared fallbacks
- Files: `packages/nextjs/services/web3/wagmiConfig.tsx:20-30`; `packages/nextjs/scaffold.config.ts:28-37`; `docs/implementation/handover.md:9-15,23-27`.
- Handover tells the payer to export and change brand.json, but RPC transport does not read that JSON. `rpcOverrides` is empty and Alchemy defaults to the scaffold shared key. Changing chainId to Base therefore sends frequent 1-second Round polls plus other reads/log scans to bare public/shared endpoints. Even with a custom primary key, bare public fallback remains. Static-host env changes cannot repair an already-built client bundle. Missing dedicated provider configuration is a pilot availability and privacy problem, not just a cosmetic default.
- Fix: document and wire a dedicated build-time `NEXT_PUBLIC_*` Base/Sepolia RPC override, prohibit accidental public fallback in the pilot artifact, restrict exposed provider credentials by host, and verify the built artifact and deployed host use that transport. For genuine post-export provider replacement, add a validated runtime RPC setting and use it consistently.

### Medium — primary actions conceal chain switching and ERC-20 approval
- Files: `packages/nextjs/components/rounds/RoundPage.tsx:134,147-175,391-400`; `packages/nextjs/components/rounds/ThresholdRoundPage.tsx:92,100-134,391-398` (claims at RoundPage:431 and ThresholdRoundPage:443).
- A wrong-chain wallet still sees Buy/Sell/Stake/Claim. Clicking can switch network and then immediately request approval/trade. Insufficient allowance still displays Buy/Stake and triggers two wallet operations. There is no action-slot branch for Switch or Approve as required by the supplied QA skill. This is not a silent wrong-chain write: the implementation awaits the switch and reports failure. It is an undisclosed sequence of signing requests, particularly disruptive during a 5–30-second trading phase.
- Fix: render one explicit primary action from connected status, chain and current allowance: Connect → Switch to Base → Approve amount → Buy/Stake; require a fresh user action/review between steps and show Claim's switch branch too.

### Medium — deployed contract, authority and privacy are absent from Player pages
- Files: `packages/nextjs/components/rounds/RoundPage.tsx:465-467`; `packages/nextjs/components/rounds/ThresholdRoundPage.tsx:543-546`; `packages/nextjs/components/rounds/ProofPanels.tsx:31-74`.
- Pages show the operator's name and balances but never render the contract address being approved/paid. They also omit the payer's future-Round reader/settings authority, public transaction/position linkability, and RPC/WalletConnect metadata exposure. Deployment docs explain owner powers to the operator, but players cannot inspect those assumptions in their flow. Contracts can change future reader/settings without a timelock (UpDownRounds.sol:187-208; ThresholdPots.sol:228-240).
- Fix: add a persistent contract identity section using Address (chain/explorer/copy), stake asset identity and concise trust/privacy disclosure. Explain that current materialized Rounds retain settings, future ones can change, outcomes depend on pinned pool readings, and timeout refunds/direct claims remain available. Surface owner/address and use a Safe for pilot ownership.

### Medium — no root license grants frontend/script fork-and-operate rights
- File: root `package.json:1` / repository root (missing LICENSE); `docs/implementation/handover.md:35`.
- No project LICENSE/LICENCE file exists in tracked source; root and Next package metadata contain no license grant. Solidity SPDX identifiers alone do not license the complete frontend, bot, scripts and handover docs. Payer receipt of out/ does not establish permission for third parties to fork/modify/operate the stack. This fails the supplied CROPS Free requirement; not a runtime contract vulnerability.
- Fix: add an explicit OSI-approved license covering the stack (with required upstream notices and ownership authority), and include the license/source commit with handover artifacts.

### Low — static handover link previews point at localhost and retain scaffold identity
- Files: `packages/nextjs/utils/scaffold-eth/getMetadata.ts:3-6,17`; `packages/nextjs/app/rounds/page.tsx:7`; `packages/nextjs/app/layout.tsx:18-21`; `README.md:1`.
- A generic static export without VERCEL_PROJECT_PRODUCTION_URL emits absolute OG/Twitter image URLs at localhost:3000, inaccessible to external unfurlers. Rounds metadata inherits the Speedrun Ethereum title suffix, favicon remains the scaffold asset, wallet appName is scaffold-eth-2, and README starts with the template challenge. This undermines white-label handover and actual link previews.
- Fix: require a public site URL when exporting, validate generated OG image URLs, brand page metadata/favicon/wallet application name and provide an app-specific README. Footer scaffold links are already hidden on /rounds and are not a finding there.

### Low — Phantom is missing from the explicit wallet catalog
- File: `packages/nextjs/services/web3/wagmiConnectors.tsx:20-28`.
- Browser modal and source omit Phantom. Do not claim no possible injected-wallet route exists; the supported dedicated option required by supplied QA is absent.
- Fix: add phantomWallet, then test injected and mobile connection on the pilot chain.

### Low — disabled pool read displays an indefinite loading message for unconfigured Campaign
- Files: `packages/nextjs/components/rounds/ProofPanels.tsx:39-41`; `packages/nextjs/utils/rounds/proof.ts:133`.
- Both actual sample pages correctly say Campaign not configured, but Pool balance simultaneously says Reading the contract… forever because the zero-address query is disabled.
- Fix: hide this panel or show Configuration required when the address is zero.

## Verification actually executed

- Started Next development server on localhost:3021 from the clean checkout (the first sandbox attempt could not bind; elevated local execution succeeded).
- Actual Playwright browser: loaded `/rounds?brand=DEGEN`; observed Degen identity, explicit Campaign not configured, header Connect Wallet, no scaffold header/footer, and disabled-query pool loading issue. Opened Connect Wallet modal and observed MetaMask, WalletConnect, Ledger, Base, Rainbow and Burner Wallet; no Phantom.
- Actual Playwright browser: loaded `/rounds?brand=BASE&market=threshold`; observed Base identity and explicit Threshold Campaign not configured gate.
- Page title was `Token Rounds | Speedrun Ethereum`. Console observed refused localhost:8545 connection with no Anvil running and normal development Lit warning. This is not reported as a production RPC error.
- Browser artifacts: `/private/tmp/flashstep-qa-15/.playwright-cli/page-2026-11-02T03-02-12-368Z.yml` (wallet menu), `page-2026-11-02T03-02-19-979Z.yml` (Base threshold gate).
- Source confirms pending is held through approval, trade receipt and catch/finally, human-readable inline errors, exact amount allowances, receipt-success checks on writes, quote review guards and contract-level round identifiers. Although raw useWriteContract differs from skill preference, it is not itself a missing-confirmation finding here. Up/down approval receipt lacks explicit status check, but a failed approval then fails simulation; no unsupported fund-loss claim.

## Verification NOT executed / pilot release gates

- No connected wallet, wrong-chain actual switch, real ERC-20 approval, buy/sell/stake/claim/rejection, target-chain browser transaction, physical phone/WalletConnect wallet-app handoff, Phantom, Safe ownership verification, deployed RPC plan/origin restrictions, actual deployed address bytecode/source verification or production host CSP was verified.
- Samples are intentionally zero-address local configurations; these are not alleged production address errors. Supply the real pilot configuration and execute all three wallet states and ETH/ERC-20 flows against it before claiming QA passes.
- Parent owns compilation/tests, deployment/export/smoke results; those are not counted as this independent review's executed results. Prior documentation's historic browser runs were read but were not re-executed by this reviewer.
- Source contains no dedicated WalletConnect mobile wallet-app return logic in either transact path. Whether current wallet behavior supplies adequate handoff needs a physical-phone run; it is an unverified acceptance criterion, not a claimed reproduced phone failure.

## CROPS Review

Chosen default:
- Existing architecture: payer-owned, non-upgradeable onchain UpDownRounds and ThresholdPots on Base; external wallet custody, permissionless settlement/refund/claim; static white-label frontend; independent unprivileged settle bot; Uniswap-style pinned TWAP reader. This avoids a required proprietary backend/indexer and custodial app accounts. Recommended pilot default: same contracts plus payer Safe ownership, dedicated configurable RPC, licensed pinned source/static artifact and explicit Player trust disclosures.

Censorship Resistance:
- Risk: frontend host/domain and RPC provider can deny access, WalletConnect/wallet vendors can deny their connection path, Base sequencer can delay inclusion, pool observation availability or missed exact boundaries can prevent normal outcomes. Payer can stop future Rounds and withdraw only unreserved funding; it cannot rewrite materialized Round outcomes. No current-Round blacklist/pause/sweep was found in inspected Round contracts.
- Mitigation: settlement/capture/claim are permissionless; missing-reading grace and 24-hour expiry enable refunds; static export and bot source are available. Handover documents rebuilding and replacement hosting. Provider replacement remains build-time and needs the finding above fixed. Production host, RPC and deployed owner identities are unknown and must be recorded.
- User escape: users with signing access can call claim(roundId) directly via an alternate RPC/frontend and ABI, without the bot or host; eligible refunds persist via claim/settle. Publish a concrete deployed-address direct-claim runbook and alternate access URL. No Base L1 forced-inclusion/bridge escape was researched or verified in this review, so none is asserted. Document verified chain-specific emergency routes before making that claim to players.

Open (visibility):
- Risk: clean commit contains frontend, bot, contracts, ABIs and deployment/self-host docs, but no pinned live URL/artifact hash, live address list/verification proof, actual production host configuration or production RPC setup is provided. A mutable served brand.json can redirect users to a different contract; frontend host/config control is a real trust power.
- Mitigation: preserve ff6a588 (or the eventual release commit), dependency lockfile, exported artifact hash and actual brand.json alongside contract addresses/verified source and host headers. Static export is a positive concrete self-host path; source does not require a private business-logic API.
- User escape: rebuild and host the pinned frontend plus matching ABIs/address config; use direct contract tooling if the host disappears. Publish that package and runbook to players, rather than only transferring out/ to the payer.

Free, as in Freedom (license):
- Risk: missing project license leaves frontend/scripts/doc rights unknown; Solidity SPDX is narrower than the full stack. No license-stability commitment was found.
- Mitigation: choose and grant an OSI-approved full-stack license with upstream notices; preserve the licensed release and source artifact for handover.
- User escape: not established legally until an explicit grant exists. After licensing, users can fork/modify/run the release without operator permission.

Privacy:
- Risk: public wallet addresses, Round participation/outcomes, positions, transfers, amounts and timing are linkable onchain. RPCs receive address/read and transaction queries plus network metadata; frontend hosts receive IP/request metadata; wallet/WalletConnect vendors may see connection/session metadata. Social sharing intentionally gives X/Telegram the Round URL and selected brand. Browser burner storage adds sensitive signing-key exposure. There is no UI privacy disclosure or RPC UI override. Installed RainbowKit is 2.2.11, but actual external telemetry traffic was not audited, so no specific telemetry-default claim is made.
- Mitigation: no account/identity service or bespoke app analytics was found in the reviewed Round flow. Use user-owned wallets, disable production burner, document public data and providers before connection, make RPC replaceable and audit production network requests.
- User escape: browse without connecting (queries use zero address for positions); avoid social share links; use an alternate/self-hosted client and RPC. These routes do not erase chain history or make wallet reuse private.

Security:
- Risk: payer controls settings for future Rounds, reader selection, stopping and unreserved withdrawals; owner type/live address is unverified. There is no timelock, though current materialized Round snapshots are protected. The contract holds stake assets and the external wallet controls player signatures. Pool manipulation/Sybil stake-cap economics, reader validity and exact-boundary bot inclusion affect fair outcomes. ERC-20 issuers may freeze/blacklist or change behavior (USDC is a documented example token); deployed stake asset is unknown. Base/sequencer/bridge and provider liveness remain external dependencies.
- Mitigation: contracts are non-upgradeable, no result override/sweep found, allowances are exact amounts, writes simulated and receipt-checked, reserved-fund checks and nonReentrant guards exist. Timeout refunds and claims have no expiry. Payer docs recommend Safe ownership and explain powers, and deployment vetting ties stake asset to pool quote; verify these actually hold for the live pilot. Add Player disclosures and production wallet/RPC fixes. Stake-cap rule is documented as an assumption-based rule, not a proof against a coordinated many-address attacker; refresh pool evidence before deployment.
- User escape: if team/bot/host disappears, user can claim already settled wins or eventually eligible refunds directly. Team disappearance can turn uncaptured Rounds into refunds rather than normal outcomes, but should not require team permission to retrieve eligible net payments/stakes. An issuer freeze, lost wallet key/browser burner storage, or chain outage can defeat immediate exit; disclose them. No complete contract audit was performed here.

Accepted compromises:
- Explicit existing product choice: real-money payer-operated Campaigns, pool-TWAP-derived outcomes, short trading/windows, and timeout refunds for missed required Readings. ADR 0004 records the operator/legal choice; this review adds no legal approval requirement.
- Static hosting with runtime brand selection is a bounded convenience tradeoff only with HTTPS/config integrity and published contract identities/artifact record.
- Base sequencing, public transaction visibility and third-party wallet/RPC metadata are architecture compromises that still require Player-facing disclosure and verified live configuration. Missing production RPC provisioning, production burner exposure, absent full-stack license and unexecuted live/phone acceptance tests are unresolved findings, not accepted compromises.

## Remote preview check (subsequent parent-provided artifact)

Actually opened `https://orekamarket-mzeccijcw-gadillacers-projects.vercel.app/rounds/?brand=DEGEN` once in Playwright. It redirected to `vercel.com/login` and displayed `Login – Vercel`, so unauthenticated users cannot reach the Campaign. No authentication bypass was attempted. Snapshot: `/private/tmp/flashstep-qa-15/.playwright-cli/page-2026-11-02T03-04-22-251Z.yml`. Parent reports this static artifact uses ff6a588 and artifact-only chainId 84532/explorer changes, with zero addresses because no Campaign is deployed. This is an intentionally gated demonstration artifact, not verified pilot functionality. If the intent is an externally accessible payer/player preview, configure public preview access or explicitly authorize recipients; this access gate must be resolved for public pilot use.

Parent separately reports a passing local real-contract handover Playwright smoke with Tie/Unmatched fixtures. That is useful shared evidence, but is not independent execution by this reviewer and does not cover real mobile wallets, production addresses, owner identities, RPC provisioning or the protected remote frontend.
