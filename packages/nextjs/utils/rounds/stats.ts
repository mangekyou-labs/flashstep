// Payer Campaign stats, derived only from contract events. Dependency-free so `node --test` runs it.

/** A decoded log, as viem's `parseEventLogs` returns it. */
export type RoundLog = { eventName: string; args: Record<string, unknown> };

export type RoundStats = {
  market: "updown" | "threshold";
  id: bigint;
  /** Stake-token units traded: up/down buy cost plus sell proceeds; threshold player stakes. */
  volume: bigint;
  players: number;
  status: "open" | "settled" | "refunded";
  /** Payer profit (+) or loss (-) on seeded liquidity or Opening stakes; undefined until the Round ends. */
  payerPnl: bigint | undefined;
};

const SHARE_SCALE = 10n ** 18n;
const UP = 1;
const DOWN = 2;
const YES = 1;
const NO = 2;

type Draft = { id: bigint; volume: bigint; players: Set<string>; result?: number; refunded: boolean };

function group<T extends Draft>(logs: RoundLog[], make: (id: bigint) => T, apply: (round: T, log: RoundLog) => void) {
  const rounds = new Map<bigint, T>();
  for (const log of logs) {
    const id = log.args.roundId as bigint;
    let round = rounds.get(id);
    if (!round) rounds.set(id, (round = make(id)));
    if (log.eventName === "Settled") round.result = Number(log.args.result);
    else if (log.eventName === "Refunded") round.refunded = true;
    else apply(round, log);
  }
  return [...rounds.values()].sort((a, b) => (a.id < b.id ? -1 : 1));
}

function status(round: Draft): RoundStats["status"] {
  return round.refunded ? "refunded" : round.result === undefined ? "open" : "settled";
}

/**
 * Up/down Rounds. Settlement keeps exactly what winners are owed, so the payer's result is the
 * players' net payment minus that payout, computed per player as the contract does.
 * `payout` is the contract's PAYOUT(): raw units paid per whole winning share.
 */
export function upDownRoundStats(logs: RoundLog[], payout: bigint): RoundStats[] {
  type Up = Draft & { net: bigint; shares: Map<string, [bigint, bigint]> };
  const drafts = group<Up>(
    logs,
    id => ({ id, volume: 0n, players: new Set(), refunded: false, net: 0n, shares: new Map() }),
    (round, { eventName, args }) => {
      if (eventName !== "Bought" && eventName !== "Sold") return;
      const player = String(args.player).toLowerCase();
      const held = round.shares.get(player) ?? [0n, 0n];
      const side = Number(args.side);
      const shares = args.shares as bigint;
      if (eventName === "Bought") {
        round.players.add(player);
        round.volume += args.cost as bigint;
        round.net += args.cost as bigint;
        held[side] += shares;
      } else {
        round.volume += args.proceeds as bigint;
        round.net -= args.proceeds as bigint;
        held[side] -= shares;
      }
      round.shares.set(player, held);
    },
  );
  return drafts.map(round => {
    let payerPnl: bigint | undefined;
    if (round.refunded || round.result === undefined) payerPnl = round.refunded ? 0n : undefined;
    else if (round.result !== UP && round.result !== DOWN) payerPnl = 0n;
    else {
      const side = round.result === UP ? 0 : 1;
      let owed = 0n;
      for (const held of round.shares.values()) owed += (held[side] * payout) / SHARE_SCALE;
      payerPnl = round.net - owed;
    }
    return {
      market: "updown",
      id: round.id,
      volume: round.volume,
      players: round.players.size,
      status: status(round),
      payerPnl,
    };
  });
}

/**
 * Threshold Rounds. The payer holds the Opening stake on both sides and is paid like any winner:
 * its winning stake times the pot over the winning side. Tie, Unmatched and refunds return it.
 */
export function thresholdRoundStats(logs: RoundLog[]): RoundStats[] {
  type Pot = Draft & { payer?: string; opening: bigint; yes: bigint; no: bigint; payerYes: bigint; payerNo: bigint };
  const drafts = group<Pot>(
    logs,
    id => ({
      id,
      volume: 0n,
      players: new Set(),
      refunded: false,
      opening: 0n,
      yes: 0n,
      no: 0n,
      payerYes: 0n,
      payerNo: 0n,
    }),
    (round, { eventName, args }) => {
      if (eventName === "RoundSeeded") {
        round.payer = String(args.payer).toLowerCase();
        round.opening = args.openingStake as bigint;
        round.yes += round.opening;
        round.no += round.opening;
        round.payerYes += round.opening;
        round.payerNo += round.opening;
      } else if (eventName === "Staked") {
        const player = String(args.player).toLowerCase();
        const amount = args.amount as bigint;
        const yes = Number(args.side) === 0;
        if (yes) round.yes += amount;
        else round.no += amount;
        // A payer staking beyond its Opening stake is part of its own result, not player volume.
        if (player === round.payer) {
          if (yes) round.payerYes += amount;
          else round.payerNo += amount;
          return;
        }
        round.players.add(player);
        round.volume += amount;
      }
    },
  );
  return drafts.map(round => {
    let payerPnl: bigint | undefined;
    if (round.refunded) payerPnl = 0n;
    else if (round.result === undefined) payerPnl = undefined;
    else if (round.result !== YES && round.result !== NO) payerPnl = 0n;
    else {
      const pot = round.yes + round.no;
      const [stake, side] = round.result === YES ? [round.payerYes, round.yes] : [round.payerNo, round.no];
      payerPnl = (stake * pot) / side - (round.payerYes + round.payerNo);
    }
    return {
      market: "threshold",
      id: round.id,
      volume: round.volume,
      players: round.players.size,
      status: status(round),
      payerPnl,
    };
  });
}

export type CampaignTotals = {
  volume: bigint;
  settledRounds: number;
  payerPnl: bigint;
  campaignCost: bigint;
  /** Payer profit or loss on Rounds, minus what the Campaign cost. */
  net: bigint;
};

/** Totals across every Round; profit or loss counts only Rounds that have ended. */
export function campaignTotals(rounds: RoundStats[], campaignCost: bigint): CampaignTotals {
  let volume = 0n;
  let payerPnl = 0n;
  let settledRounds = 0;
  for (const round of rounds) {
    volume += round.volume;
    if (round.payerPnl === undefined) continue;
    payerPnl += round.payerPnl;
    settledRounds++;
  }
  return { volume, settledRounds, payerPnl, campaignCost, net: payerPnl - campaignCost };
}
