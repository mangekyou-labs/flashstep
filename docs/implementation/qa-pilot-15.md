# Pilot QA rehearsal: issue 15

Date: 2026-11-02. Source: `ff6a588e321b3ab2eaa59e5151329c2ea0a1d77a` (main after PR 29).

**Decision: not ready to pilot.** The new frontend preview is deployed; a Base Sepolia Campaign has not been deployed. The owner confirmed this during QA. Contract deployment, verification, funded live Rounds, live bot operation, target-chain wallet tests and real-phone wallet tests remain outstanding. Local fixtures do not satisfy those acceptance criteria.

## Test links and deployment

- [Up/down preview](https://orekamarket-mzeccijcw-gadillacers-projects.vercel.app/rounds/?brand=DEGEN)
- [Threshold preview](https://orekamarket-mzeccijcw-gadillacers-projects.vercel.app/rounds/?brand=DEGEN&market=threshold)
- [Payer stats preview](https://orekamarket-mzeccijcw-gadillacers-projects.vercel.app/rounds/stats/?brand=DEGEN)
- [Vercel deployment](https://vercel.com/gadillacers-projects/orekamarket/CYuoRKL77VHbWzMJjbEz5zqNsti8), ID `dpl_CYuoRKL77VHbWzMJjbEz5zqNsti8`, target preview, status Ready.

The existing Vercel project is `orekamarket` in `gadillacers-projects`. Its preview authentication protection remains enabled: visitors must sign in with an authorized Vercel account. Production was not updated.

The deployed artifact is the handover static export, built with `yarn install --immutable` and `yarn handover:export`. It does not include the dirty original workspace. In the artifact only, each brand's `chainId` is 84532 and `explorerUrl` is `https://sepolia.basescan.org`; both contract addresses remain zero. This is an unconfigured preview, not a working testnet Campaign. `qa-build.json` in the artifact records that provenance. Do not fund an address taken from this placeholder configuration.

The deployment config disables server-side installation/build and serves the already built files. It redirects `/` to `/rounds/` and sets `Content-Security-Policy: frame-ancestors *` on the Round routes, matching the handover's embed default. It does not change the project's production settings.

## Frontend validation

Passed against the isolated checkout:

- `yarn next:check-types`.
- `yarn next:lint --max-warnings=0`.
- `node --test packages/nextjs/utils/rounds/*.test.ts`: 21 passed, 0 failed.
- `yarn handover:export`: 12 static routes exported.
- `node scripts/handover-smoke.mjs`: actual Playwright CLI against static export and disposable local Anvil; up/down displayed a Tie and threshold displayed an Unmatched refund. The script cleaned up its browser, chain and static server. This is local evidence, not a Base Sepolia smoke pass.

See the [independent ETHSKILLS report and full CROPS Review](qa-15/ethskills-review.md), [contract evidence](qa-15/contract-evidence.md), [raw scanner output](qa-15/logs/slither.log), [fuzz/invariant statistics](qa-15/logs/fuzz-invariant-stats.txt) and [pinned fork traces](qa-15/logs/forge-base-fork.log) for their scope and findings. The reviewer used a fresh agent context and the current [qa](https://ethskills.com/qa/SKILL.md) and [crops](https://ethskills.com/crops/SKILL.md) checklists.

## Filed findings

- [QA: High — local-only burner protection is bypassed for a real-money Base Campaign](https://github.com/mangekyou-labs/flashstep/issues/30)
- [QA: Medium — production handover has no RPC provisioning path and retains public/shared fallbacks](https://github.com/mangekyou-labs/flashstep/issues/31)
- [QA: Medium — primary actions conceal chain switching and ERC-20 approval](https://github.com/mangekyou-labs/flashstep/issues/32)
- [QA: Medium — deployed contract, authority and privacy are absent from Player pages](https://github.com/mangekyou-labs/flashstep/issues/33)
- [QA: Medium — no root license grants frontend/script fork-and-operate rights](https://github.com/mangekyou-labs/flashstep/issues/34)
- [QA: Low — static handover link previews point at localhost and retain scaffold identity](https://github.com/mangekyou-labs/flashstep/issues/35)
- [QA: Low — Phantom is missing from the explicit wallet catalog](https://github.com/mangekyou-labs/flashstep/issues/36)
- [QA: Low — disabled pool read displays an indefinite loading message for unconfigured Campaign](https://github.com/mangekyou-labs/flashstep/issues/37)

## Remaining owner steps

The repository's AGENTS.md says: "Deploy, verify and account commands need an interactive password prompt; leave them to the user." Issue 15 also explicitly assigns deployment to the owner. No live signing, password entry or contract verification was attempted by the agent.

1. Work from the source revision above, install its pinned dependencies and populate a settings JSON using [payer-deploy.md](payer-deploy.md#the-settings-file). Supply the Payer's public address, a vetted **Base Sepolia** Uniswap V3 pool and its base/quote token addresses. The runbook's mainnet example addresses must not be copied onto Sepolia. Check observation history, pool liquidity and the Stake cap before choosing funding amounts. Keep the JSON free of signing secrets.
2. Use a funded Base Sepolia wallet and run the existing driver from the repository root:

   ```sh
   yarn payer:deploy --config /absolute/path/to/settings.json --network baseSepolia --account payer
   ```

   `payer` is the owner's existing encrypted keystore name; substitute it as appropriate. The driver performs read-only preflight, then asks for the deployment and funding approvals. The owner handles those prompts. For a hardware wallet, use the documented `--ledger` route instead.
3. Run the exact verification commands printed by the driver, using Base Sepolia. Its explorer command is:

   ```sh
   VERIFY_SCRIPT=DeployPayerCampaign.s.sol yarn verify baseSepolia
   ```

   Run every printed Sourcify command with chain 84532 and the actual constructor arguments. Record verified source links for the reader and both Round contracts, plus the market-cap reader if present. A transaction receipt alone is not verification evidence.
4. Return the public `UpDownRounds` and `ThresholdPots` addresses, deployment block and deployment transaction hashes. Update the served brand entry's `address`, `thresholdAddress` and `fromBlock`; retain chain 84532. Re-upload the artifact as another preview. Do not edit `deployedContracts.ts` by hand.
5. Start the [settle bot](settle-bot.md) in the owner's environment with a separate gas-only wallet and a dedicated RPC. Its environment is `SETTLE_RPC_URL`, `SETTLE_PRIVATE_KEY`, `SETTLE_UPDOWN_ADDRESS`, `SETTLE_THRESHOLD_ADDRESS`, `SETTLE_FROM_BLOCK`. Do not paste its key into chat or commit it. Capture logs for successful boundary captures and settlement, and observe a restart recovering missed work.
6. Test disconnected, wrong-chain and Base Sepolia Player wallets. Run several Rounds of each market, include at least one Tie or Unmatched, and check buys/sells, cumulative cap refusal, approval ordering, receipt locking, rejection messages, outcome display and claims. Record transaction hashes and actual payouts. Test mobile WalletConnect on a real phone.
7. Run Playwright CLI against the configured Sepolia preview and attach screenshots/snapshots. An unauthenticated Vercel login page does not count as a Campaign smoke pass. Reassess the bug tickets and CROPS compromises before the owner judges pilot readiness.

## Acceptance status

- [x] Independent fresh-context qa review with severity, file and line.
- [x] Full CROPS Review, including authority and direct-claim escape path.
- [x] Actual Slither scan and fuzz/invariant statistics attached; scanner findings retained.
- [x] 19 tests against block 35,000,000 on an endpoint confirmed to serve archive reads.
- [x] Findings filed and preliminary decision recorded: not ready to pilot.

- [ ] Owner deploys/funds Campaign on Base Sepolia.
- [ ] Several Rounds of both types settle through the live bot, including Tie or Unmatched.
- [ ] Playwright CLI passes against the configured Sepolia deployment.
- [ ] All deployed Sepolia contracts verified on Basescan and Sourcify.
- [ ] Real-wallet and real-phone flows completed.
- [ ] Owner judges ready to pilot after findings are resolved or explicitly accepted.

Issue 15 stays open. This report records completed preparation and checks without converting local evidence into a live-network result.
