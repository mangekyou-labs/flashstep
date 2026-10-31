"use client";

import { CSSProperties } from "react";
import Image from "next/image";
import { formatUnits } from "viem";
import { BrandGate } from "~~/components/rounds/BrandGate";
import { type Payer } from "~~/config/payers";
import { RoundStats } from "~~/utils/rounds/stats";
import { useCampaignStats } from "~~/utils/rounds/useCampaignStats";

function signed(value: bigint, decimals: number) {
  return value > 0n ? `+${formatUnits(value, decimals)}` : formatUnits(value, decimals);
}
const statusLabel: Record<RoundStats["status"], string> = { open: "Open", settled: "Settled", refunded: "Refunded" };
const marketLabel: Record<RoundStats["market"], string> = { updown: "Up/down", threshold: "Threshold" };

/** The payer's view of its Campaign: each Round's volume, players and result, and the total against cost. */
export function CampaignStatsPage() {
  return (
    <BrandGate>
      {payer => <CampaignStatsBody key={payer.ticker} payer={payer} />}
    </BrandGate>
  );
}

function CampaignStatsBody({ payer }: { payer: Payer }) {
  const stats = useCampaignStats(payer);
  const data = stats.data;
  const decimals = data?.token.decimals ?? 18;
  const symbol = data?.token.symbol ?? "";
  return (
    <div
      className="round-page"
      style={{ "--round-accent": payer.accent, "--round-up": payer.up, "--round-down": payer.down } as CSSProperties}
    >
      <header className="round-top">
        <a href={`/rounds?brand=${payer.ticker}`} className="round-brand">
          <Image src={payer.logo} width={32} height={32} alt="" />
          <span>
            {payer.name} <span className="round-muted">Campaign stats</span>
          </span>
        </a>
      </header>
      <div className="round-content">
        <div className="round-kicker">Payer view · from contract events</div>
        {stats.isPending ? (
          <div className="round-state" role="status">
            Reading Campaign events…
          </div>
        ) : stats.isError || !data ? (
          <div className="round-state" role="alert">
            <h1>Stats unavailable</h1>
            <p>Check the Campaign network, then retry.</p>
            <button onClick={() => void stats.refetch()}>Retry</button>
          </div>
        ) : (
          <>
            <section className="round-stats-total" aria-labelledby="campaign-total-title">
              <h1 id="campaign-total-title">Campaign total</h1>
              <dl className="round-rules">
                <div>
                  <dt>Stake volume</dt>
                  <dd data-testid="total-volume">
                    {formatUnits(data.totals.volume, decimals)} {symbol}
                  </dd>
                </div>
                <div>
                  <dt>Your result on Rounds ({data.totals.settledRounds} ended)</dt>
                  <dd data-testid="total-pnl">
                    {signed(data.totals.payerPnl, decimals)} {symbol}
                  </dd>
                </div>
                <div>
                  <dt>Campaign cost</dt>
                  <dd data-testid="campaign-cost">
                    {data.totals.campaignCost === undefined
                      ? "Not configured"
                      : `${formatUnits(data.totals.campaignCost, decimals)} ${symbol}`}
                  </dd>
                </div>
                <div>
                  <dt>Total spend (cost minus result)</dt>
                  <dd data-testid="total-spend">
                    {data.totals.net === undefined
                      ? "Not configured"
                      : `${formatUnits(-data.totals.net, decimals)} ${symbol}`}
                  </dd>
                </div>
              </dl>
            </section>
            <section className="round-history">
              <h2>Rounds</h2>
              {data.rounds.length === 0 ? (
                <p className="round-muted">No Round has opened yet.</p>
              ) : (
                <div className="round-table-scroll">
                  <table data-testid="stats-table">
                    <thead>
                      <tr>
                        <th>Market</th>
                        <th>Round</th>
                        <th>Status</th>
                        <th>Volume</th>
                        <th>Players</th>
                        <th>Your profit or loss</th>
                      </tr>
                    </thead>
                    <tbody>
                      {data.rounds.map(round => (
                        <tr key={`${round.market}-${round.id}`} data-testid={`stats-${round.market}-${round.id}`}>
                          <td>{marketLabel[round.market]}</td>
                          <td>#{round.id.toString()}</td>
                          <td>{statusLabel[round.status]}</td>
                          <td>
                            {formatUnits(round.volume, decimals)} {symbol}
                          </td>
                          <td>{round.players}</td>
                          <td>
                            {round.payerPnl === undefined ? "–" : `${signed(round.payerPnl, decimals)} ${symbol}`}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
              <p className="round-muted">
                Profit or loss is on up/down Round liquidity and threshold Opening stakes, before claims. Volume counts
                player buys and stakes only.
              </p>
            </section>
          </>
        )}
      </div>
    </div>
  );
}
