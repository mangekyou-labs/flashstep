# Threshold Rounds on the Round page

Open `/rounds?brand=DEGEN&market=threshold`. Up/down and threshold Rounds have separate contract addresses and Round-number histories. The links switch between them. `thresholdAddress` in `brand.json` configures that brand, not `NEXT_PUBLIC_THRESHOLD_ADDRESS` / `NEXT_PUBLIC_BASE_THRESHOLD_ADDRESS`. Addresses never come from the URL. The existing payer branding and configured chain apply.

The threshold contract supplies the question's metric and threshold, phase, positions, Pot, payout previews and claimable amounts. `quoteStake(roundId, player, side, amount)` returns the Player's **total** payout on that side if it wins, including the entered stake and previously held same-side stakes. Zero amount previews the held position. Opening stakes are included in the Pot and side totals. Payouts use the same integer rounding as `claimable`; no payout calculation runs in TypeScript. Opposite-side holdings do not count as winning stakes. A peer joining your side can lower the payout, so every preview is labelled as the current split.

`currentValue` is a live display view. For market cap, `previewMarketCap` uses the live TWAP and vetted fixed supply, or the last completed block's checkpoint supply. The display never supplies a settlement input: settlement still uses the pinned end Reading and eligible end-block supply. If the live view fails, the page shows a waiting state while existing claims stay accessible.

Stakes use the configured asset's exact decimals. Excess precision is rejected before `parseUnits`, which otherwise rounds. ETH sends the exact stake; ERC-20 stakes approve that amount and wait for approval. After approval, phase and payout are refreshed before simulation. A changed payout requires review. The Round and amount are frozen across wallet prompts; a rollover cannot redirect the stake. Pending forms cannot change side or amount.

Tie, Unmatched and outage/expiry refunds have explicit refund labels. Claim amounts come from `claimable`, including either or both of the Player's sides. Claiming updates the position to Claimed. Claims remain accessible with `&round=<id>` or the Round lookup after leaving the recent table or after Campaign end.

## Disposable local smoke fixture

Start a disposable Anvil on port 8545 and compile contracts with `forge build --root packages/foundry`. These commands only accept localhost Anvil on chain 31337 and use unlocked test accounts; they never load keys. The fixture uses one-second transaction timestamps, so browser interactions do not race the 30-second trading phase.

```sh
node scripts/threshold-local.mjs setup yes
```

Put the printed address into `brand.json` as `thresholdAddress` and restart the frontend. Open `/rounds?brand=DEGEN&market=threshold`, connect a Player wallet, and fund it:

```sh
node scripts/threshold-local.mjs fund-player <wallet-address>
```

Stake 0.01 Yes and 0.01 No. The position shows both stakes and the contract previews. Record `To win if Yes`, add a peer to Yes, and verify it decreases:

```sh
node scripts/threshold-local.mjs stake-other yes 0.01
```

Enter an amount above the remaining 0.1 cap to verify the cumulative refusal, then restore a smaller amount. Optionally advance to cutoff and check that the current Round rolls forward and historical Round #1 refuses staking:

```sh
node scripts/threshold-local.mjs cutoff 1
node scripts/threshold-local.mjs settle 1
node scripts/threshold-local.mjs inspect <wallet-address> 1
```

View Round #1 and compare the claim button amount with the printed raw-unit `claimable`. Claim and verify Claimed, then reload and verify no further claim is offered.

Repeat setup with `no`, `tie`, `unmatched`, `marketcap` or `usdc`, updating the environment and restarting the frontend each time. `no` lowers the pool TWAP; `tie` leaves it exactly at the threshold; `unmatched` has no Opening stake, so stake only one side and settlement needs no Reading. `marketcap` uses the eligible fixed supply and shows a threshold of 1,000,000 quote tokens. `usdc` deploys a **local six-decimal mock**, named STAKE; fund-player also mints it, allowing the real approval/stake/claim flow. Settle each scenario after browser staking. All fixture state is in ignored `output/threshold-local.json`.

Run browser checks through `playwright-cli`, taking fresh snapshots before using element references. Check both brand configs, keyboard focus and 375/768/1280 widths. Browser artifacts belong under ignored `output/playwright/`.

## Verified behavior

The issue #9 local Anvil and `playwright-cli` run on 2026-10-30 passed:

| Scenario | Browser and contract evidence |
| --- | --- |
| Yes win | Player staked 0.01 ETH on each side. A peer's 0.01 Yes stake lowered the held Yes payout from 0.02 to 0.016666666666666666 ETH. Settlement returned exactly 16666666666666666 raw units; browser claim succeeded and stayed Claimed after reload. |
| Tie | Both Player stakes refunded: 0.02 ETH / 20000000000000000 raw units. Explicit Tie refund label and browser claim passed. |
| Unmatched | One 0.01 ETH stake refunded without an end Reading. Explicit Unmatched refund label and browser claim passed. |
| Six-decimal ERC-20 | Excess precision rejected; exact approval and 0.01 STAKE stake succeeded. Yes payout was 0.015 STAKE / 15000 raw units and browser claim succeeded. |
| Safety and layout | Cumulative cap disabled submission, cutoff rolled to Round #2, historical staking was disabled, and 375/768/1280 widths had no horizontal overflow. Keyboard focus remained available. |
| Display and regression | Price and market-cap questions rendered for DEGEN and BASE; market-cap threshold and current value were 1,000,000 quote tokens. Reduced-motion mode rendered normally. The original Up/Down Round #1 still showed the Player's 1 Up share. |

The merged threshold and reading suites passed 120 tests, with five opt-in fork tests skipped. TypeScript and changed-file ESLint passed. Standards review found no additional issues; spec review's lazy payer Opening-stake quote issue was reproduced, fixed, and rechecked with quote → stake → settlement → claim parity.
