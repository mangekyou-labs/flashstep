// Payer Campaign stats, derived only from contract events. Dependency-free so `node --test` runs it.

/** A decoded log, as viem's `parseEventLogs` returns it. */
export type RoundLog = { eventName: string; args: Record<string, unknown> };

export type RoundStats = {
  market: "updown" | "threshold";
  id: bigint;
  /** Stake-token units players paid in: up/down buy cost, threshold stakes. The payer's own trades are left out. */
  volume: bigint;
  players: number;
  status: "open" | "settled" | "refunded";
  /** Payer profit (+) or loss (-) on the Round; undefined until the Round ends. */
  payerPnl: bigint | undefined;
};

const SHARE_SCALE = 10n ** 18n;
const UP = 1;
const DOWN = 2;
const YES = 1;
const NO = 2;

type Draft = { id: bigint; volume: bigint; players: Set<string>; result?: number; refunded: boolean };

const lower = (address: unknown) => String(address).toLowerCase();

function group<T extends Draft>(
  logs: RoundLog[],
  make: () => Omit<T, keyof Draft>,
  apply: (round: T, log: RoundLog) => void,
) {
  const rounds = new Map<bigint, T>();
  for (const log of logs) {
    const id = log.args.roundId as bigint;
    let round = rounds.get(id);
    if (!round) rounds.set(id, (round = { id, volume: 0n, players: new Set(), refunded: false, ...make() } as T));
    if (log.eventName === "Settled") round.result = Number(log.args.result);
    else if (log.eventName === "Refunded") round.refunded = true;
    else apply(round, log);
  }
  return [...rounds.values()].sort((a, b) => (a.id < b.id ? -1 : 1));
}

/** Builds one Round's row; `ended` computes the payer result once the Round has settled or refunded. */
function roundStats(market: RoundStats["market"], round: Draft, ended: () => bigint): RoundStats {
  const status = round.refunded ? "refunded" : round.result === undefined ? "open" : "settled";
  return {
    market,
    id: round.id,
    volume: round.volume,
    players: round.players.size,
    status,
    payerPnl: status === "open" ? undefined : ended(),
  };
}

type Position = { bought: bigint; proceeds: bigint; shares: [bigint, bigint] };

/**
 * Up/down Rounds. The payer keeps players' net payments minus what the contract owes them:
 * winning shares times `payout` (PAYOUT(), raw units per whole share) on Up or Down, and each
 * player's unrecovered cost, max(bought - proceeds, 0), on a Tie or refund.
 * Trades by `payer` move money from the payer to itself, so they are left out entirely.
 */
export function upDownRoundStats(logs: RoundLog[], payout: bigint, payer?: string): RoundStats[] {
  type Up = Draft & { net: bigint; positions: Map<string, Position> };
  const self = payer && lower(payer);
  const drafts = group<Up>(
    logs,
    () => ({ net: 0n, positions: new Map() }),
    (round, { eventName, args }) => {
      if (eventName !== "Bought" && eventName !== "Sold") return;
      const player = lower(args.player);
      if (player === self) return;
      const p = round.positions.get(player) ?? { bought: 0n, proceeds: 0n, shares: [0n, 0n] };
      const side = Number(args.side);
      const shares = args.shares as bigint;
      if (eventName === "Bought") {
        round.players.add(player);
        round.volume += args.cost as bigint;
        round.net += args.cost as bigint;
        p.bought += args.cost as bigint;
        p.shares[side] += shares;
      } else {
        round.net -= args.proceeds as bigint;
        p.proceeds += args.proceeds as bigint;
        p.shares[side] -= shares;
      }
      round.positions.set(player, p);
    },
  );
  return drafts.map(round =>
    roundStats("updown", round, () => {
      let owed = 0n;
      const winner = round.refunded ? undefined : round.result === UP ? 0 : round.result === DOWN ? 1 : undefined;
      for (const p of round.positions.values()) {
        if (winner !== undefined) owed += (p.shares[winner] * payout) / SHARE_SCALE;
        else if (p.bought > p.proceeds) owed += p.bought - p.proceeds;
      }
      return round.net - owed;
    }),
  );
}

/**
 * Threshold Rounds. The payer holds the Opening stake on both sides and is paid like any winner:
 * its winning stake times the pot over the winning side, plus any dust credited after the last
 * winner claims. Tie, Unmatched and refunds return its stakes.
 */
export function thresholdRoundStats(logs: RoundLog[]): RoundStats[] {
  type Pot = Draft & { payer?: string; yes: bigint; no: bigint; payerYes: bigint; payerNo: bigint; dust: bigint };
  const drafts = group<Pot>(
    logs,
    () => ({ yes: 0n, no: 0n, payerYes: 0n, payerNo: 0n, dust: 0n }),
    (round, { eventName, args }) => {
      if (eventName === "RoundSeeded") {
        const opening = args.openingStake as bigint;
        round.payer = lower(args.payer);
        round.yes += opening;
        round.no += opening;
        round.payerYes += opening;
        round.payerNo += opening;
      } else if (eventName === "DustCredited") {
        round.dust += args.amount as bigint;
      } else if (eventName === "Staked") {
        const player = lower(args.player);
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
  return drafts.map(round =>
    roundStats("threshold", round, () => {
      if (round.refunded || (round.result !== YES && round.result !== NO)) return 0n;
      const pot = round.yes + round.no;
      const [stake, side] = round.result === YES ? [round.payerYes, round.yes] : [round.payerNo, round.no];
      return (stake * pot) / side - (round.payerYes + round.payerNo) + round.dust;
    }),
  );
}

export type CampaignTotals = {
  volume: bigint;
  settledRounds: number;
  payerPnl: bigint;
  /** Undefined when the Campaign cost is not configured. */
  campaignCost: bigint | undefined;
  /** Payer profit or loss on Rounds, minus what the Campaign cost; undefined without a cost. */
  net: bigint | undefined;
};

/** Totals across every Round; profit or loss counts only Rounds that have ended. */
export function campaignTotals(rounds: RoundStats[], campaignCost: bigint | undefined): CampaignTotals {
  let volume = 0n;
  let payerPnl = 0n;
  let settledRounds = 0;
  for (const round of rounds) {
    volume += round.volume;
    if (round.payerPnl === undefined) continue;
    payerPnl += round.payerPnl;
    settledRounds++;
  }
  const net = campaignCost === undefined ? undefined : payerPnl - campaignCost;
  return { volume, settledRounds, payerPnl, campaignCost, net };
}
