// Run with: node --test packages/nextjs/utils/rounds/stats.test.ts (Node 24 strips the types).
import { campaignTotals, thresholdRoundStats, upDownRoundStats } from "./stats.ts";
import assert from "node:assert/strict";
import { test } from "node:test";

const E = 10n ** 16n; // 0.01 of an 18-decimal token
const A = "0x000000000000000000000000000000000000000a";
const B = "0x000000000000000000000000000000000000000b";
const PAYER = "0x00000000000000000000000000000000000000ff";
const SHARE = 10n ** 18n;

const upDownLogs = (result: number) => [
  { eventName: "RoundSeeded", args: { roundId: 1n, seed: 100n * E } },
  { eventName: "Bought", args: { roundId: 1n, player: A, side: 0, shares: 10n * SHARE, cost: 6n * E } },
  { eventName: "Bought", args: { roundId: 1n, player: B, side: 1, shares: 5n * SHARE, cost: 3n * E } },
  { eventName: "Sold", args: { roundId: 1n, player: A, side: 0, shares: 2n * SHARE, proceeds: 1n * E } },
  { eventName: "Settled", args: { roundId: 1n, result } },
];

test("up/down Round: volume, players and payer profit when Down wins", () => {
  const [round] = upDownRoundStats(upDownLogs(2), 1n * E);
  assert.equal(round.id, 1n);
  assert.equal(round.volume, 10n * E);
  assert.equal(round.players, 2);
  assert.equal(round.status, "settled");
  // Players paid in 0.08 net; 5 Down shares pay 0.05.
  assert.equal(round.payerPnl, 3n * E);
});

test("up/down Round: payer breaks even when Up wins here, and on a Tie", () => {
  assert.equal(upDownRoundStats(upDownLogs(1), 1n * E)[0].payerPnl, 0n);
  assert.equal(upDownRoundStats(upDownLogs(3), 1n * E)[0].payerPnl, 0n);
});

test("up/down Round: open Round has no profit or loss yet; refunded Round is zero", () => {
  const open = upDownRoundStats(upDownLogs(2).slice(0, 4), 1n * E)[0];
  assert.equal(open.status, "open");
  assert.equal(open.payerPnl, undefined);
  const refunded = upDownRoundStats(
    [...upDownLogs(2).slice(0, 4), { eventName: "Refunded", args: { roundId: 1n } }],
    1n * E,
  )[0];
  assert.equal(refunded.status, "refunded");
  assert.equal(refunded.payerPnl, 0n);
});

const thresholdLogs = (result: number) => [
  { eventName: "RoundSeeded", args: { roundId: 7n, payer: PAYER, openingStake: 100n * E } },
  { eventName: "Staked", args: { roundId: 7n, player: A, side: 0, amount: 50n * E } },
  { eventName: "Staked", args: { roundId: 7n, player: B, side: 1, amount: 20n * E } },
  { eventName: "Settled", args: { roundId: 7n, result } },
];

test("threshold Round: payer's Opening stakes lose 0.2 when Yes wins", () => {
  const [round] = thresholdRoundStats(thresholdLogs(1));
  assert.equal(round.volume, 70n * E);
  assert.equal(round.players, 2);
  // Pot 2.7, Yes side 1.5: the payer's 1 Yes takes 1.8 of its 2 staked.
  assert.equal(round.payerPnl, -20n * E);
});

test("threshold Round: payer wins 0.25 when No wins; Unmatched, Tie and Refunded are zero", () => {
  // Pot 2.7, No side 1.2: the payer's 1 No takes 2.25.
  assert.equal(thresholdRoundStats(thresholdLogs(2))[0].payerPnl, 25n * E);
  for (const result of [3, 4]) assert.equal(thresholdRoundStats(thresholdLogs(result))[0].payerPnl, 0n);
  const refunded = [...thresholdLogs(1).slice(0, 3), { eventName: "Refunded", args: { roundId: 7n } }];
  assert.equal(thresholdRoundStats(refunded)[0].status, "refunded");
});

test("Campaign total adds settled Rounds and sets them against the Campaign cost", () => {
  const rounds = [
    ...upDownRoundStats(upDownLogs(2), 1n * E),
    ...thresholdRoundStats(thresholdLogs(1)),
    ...upDownRoundStats(
      upDownLogs(2)
        .slice(0, 4)
        .map(l => ({ ...l, args: { ...l.args, roundId: 2n } })),
      1n * E,
    ),
  ];
  const total = campaignTotals(rounds, 500n * E);
  assert.equal(total.volume, 90n * E);
  assert.equal(total.settledRounds, 2);
  assert.equal(total.payerPnl, -17n * E);
  assert.equal(total.campaignCost, 500n * E);
  assert.equal(total.net, -517n * E);
});
