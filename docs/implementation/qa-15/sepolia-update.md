# Base Sepolia deployment update — 2026-11-03

> **2026-11-04 live bot:** [Round 1 refunded in both contracts; later captures missed](live-bot-status.md). Native 200ms block timing contradicts the bot's two-second next-block assumption. Normal settlement QA is blocked pending a timing fix.

> **2026-11-04:** [Owner-run verification completed on both providers](verification-status.md). Earlier verification-pending statements below are historical. Bot and live-wallet QA remain outstanding.

The owner deployed, funded and seeded both contracts. This supersedes the 2026-11-02 report's missing-Campaign status; that report remains the initial review record.

## Configured preview

- [Up/down](https://orekamarket-ll8t6osct-gadillacers-projects.vercel.app/rounds/?brand=WETH)
- [Threshold](https://orekamarket-ll8t6osct-gadillacers-projects.vercel.app/rounds/?brand=WETH&market=threshold)
- [Deployment](https://vercel.com/gadillacers-projects/orekamarket/73GAbPxYVPhWyf8dGXEs2jgq9HV5), preview, existing Vercel authentication retained.

Source bundle remains ff6a588; only runtime brand/provenance JSON changed. WETH is the actual price reference and USDC the quote/stake asset. WETH, DEGEN and BASE keys are aliases for this single QA Campaign; WETH matches generated navigation. [Runtime config](sepolia-brand.json) and [artifact hashes](sepolia-artifact-sha256.txt) are preserved.

## Onchain evidence

Chain 84532; scan from block **53,908,146**. Public [deployment receipts](sepolia-deployment.json) and [RPC readback](sepolia-readback.json) contain no signing/cache data.

| Contract | Address |
| --- | --- |
| UpDownRounds | [0xB5087655A30e42b5C2DB89078e0490221E91D33e](https://sepolia.basescan.org/address/0xB5087655A30e42b5C2DB89078e0490221E91D33e) |
| ThresholdPots | [0xe80Cd5E09C4949639bb6D9dBf5E36E8Ac3130ebe](https://sepolia.basescan.org/address/0xe80Cd5E09C4949639bb6D9dBf5E36E8Ac3130ebe) |
| BasePoolReader | [0x8De98D34Fa14867a9e7EbC3b59Ee25992B5B7D94](https://sepolia.basescan.org/address/0x8De98D34Fa14867a9e7EbC3b59Ee25992B5B7D94) |

Both owners read back as `0xeD37FD0d6F0f69236E7472B36796e133D20EcC32`; both readers/stake tokens match the deployed config. UpDown holds 60,000 raw test USDC: 40,000 available + 20,000 reserved. Threshold holds 20,000: 18,000 available + 2,000 reserved. USDC has six decimals, so total funding is 0.08 test USDC. Stake cap is 500 raw = 0.0005 USDC; use smaller test amounts, rather than the page's 0.01 default.

Pool `0x94bfc0574FF48E92cE43d495376C477B1d0EEeC0` was read from the script's Base Sepolia factory for WETH/test-USDC at fee500; its 30-second observe call returned values. At the initial check, quote balance was 462,483,816 raw, giving the configured model's 1,122-raw cap versus configured500. Owner preflight passed. This shallow testnet pool is for QA only; it is not the qualifying mainnet pool evidence and has no economic safety claim.

## Browser evidence and remaining gates

Playwright CLI loaded the exact configured static artifact at localhost3022 while reading the deployed Base Sepolia contracts. UpDown loaded live Round data. Threshold displayed the WETH price question, 2,000 USDC threshold, 0.0005 cap, 0.02 pool balance, and disconnected Connect to stake action. [Threshold snapshot](browser/sepolia-threshold-local.txt) and [screenshot](browser/sepolia-threshold-local.png) are attached. Browser/server were stopped after the check. This is a locally served frontend against Sepolia, not an authenticated smoke of the Vercel host.

[Console output](browser/sepolia-console.log) records repeated HTTP429 from the public `sepolia.base.org` RPC and a local8545 probe from the existing wallet setup. This confirms #31's public/shared-RPC availability risk; no clean end-to-end pass is claimed. Source wallet/network findings remain open.

At block53,909,074, Round1 in both contracts still had stored result0 (unsettled). No bot, Player transaction or direct claim was executed by the agent. Current schedule pointer advancement does not prove multiple materialized/settled Rounds.

Still required: owner source verification on Basescan and Sourcify; dedicated RPC setup; a dedicated gas-funded bot wallet running the bot; several live Rounds of both types including Tie/Unmatched; real-wallet and phone checks; authenticated hosted Playwright pass; findings resolved/accepted. **Not ready to pilot; #15 stays open.**

## Next owner commands

From `/private/tmp/flashstep-qa-15`, run `VERIFY_SCRIPT=DeployPayerCampaign.s.sol yarn verify baseSepolia`, followed by the three exact Sourcify commands printed by the successful deploy driver (run Forge from `packages/foundry`). The agent has not run verification per AGENTS.md.

For the bot, provide its dedicated key only through your local process environment/secret store; never paste it into chat. Use the matching ABI artifacts and `yarn settle:bot` from the QA checkout root with:

```sh
export SETTLE_UPDOWN_ADDRESS=0xB5087655A30e42b5C2DB89078e0490221E91D33e
export SETTLE_THRESHOLD_ADDRESS=0xe80Cd5E09C4949639bb6D9dBf5E36E8Ac3130ebe
export SETTLE_FROM_BLOCK=53908146
# Set SETTLE_RPC_URL to your Base Sepolia provider.
# Set SETTLE_PRIVATE_KEY via your local secret store to a separate gas-funded bot key.
yarn settle:bot
```

The bot does not automatically load `.env`. Keep its JSON logs/transaction hashes as live QA evidence, including restart recovery. Source verification and a running bot are separate gates; neither follows automatically from deployment success.
