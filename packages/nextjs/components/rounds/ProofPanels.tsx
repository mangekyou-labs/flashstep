"use client";

import { useState } from "react";
import { formatUnits } from "viem";
import { Market, Payer } from "~~/config/payers";
import {
  FinishedRound,
  explorerTxUrl,
  isFinished,
  roundUrl,
  shareLinks,
  useOrigin,
  usePoolBalance,
  useSettleTxs,
} from "~~/utils/rounds/proof";

/** The Round's share links and its pool balance, shown together under the Round card. */
export function ProofPanels({ payer, market, roundId }: { payer: Payer; market: Market; roundId?: bigint }) {
  return (
    <>
      <ShareBar payer={payer} market={market} roundId={roundId} />
      <PoolBalance payer={payer} market={market} />
    </>
  );
}

/** What the contract holds to pay winners: its real balance, read at one block. */
function PoolBalance({ payer, market }: { payer: Payer; market: Market }) {
  const pool = usePoolBalance(payer, market);
  const data = pool.data;
  const format = (value: bigint) => formatUnits(value, data?.decimals ?? 18);
  return (
    <section className="round-pool" aria-labelledby="round-pool-title">
      <h2 id="round-pool-title">Pool balance</h2>
      {pool.isError ? (
        <p className="round-muted">
          Could not read the pool. <button onClick={() => void pool.refetch()}>Retry</button>
        </p>
      ) : !data ? (
        <p className="round-muted">Reading the contract…</p>
      ) : (
        <>
          <p className="round-pool-total" data-testid="pool-balance">
            <strong>
              {format(data.held)} {data.symbol}
            </strong>{" "}
            held by the contract to pay winners
          </p>
          <dl className="round-rules">
            <div>
              <dt>Committed to open Rounds</dt>
              <dd data-testid="pool-reserved">
                {format(data.reserved)} {data.symbol}
              </dd>
            </div>
            <div>
              <dt>Available for new Rounds</dt>
              <dd data-testid="pool-funding">
                {format(data.funding)} {data.symbol}
              </dd>
            </div>
          </dl>
        </>
      )}
    </section>
  );
}

type SettleTxs = ReturnType<typeof useSettleTxs>;

/** The "Settle tx" table cell, shared by both Round tables. */
export function SettleTxCell({ payer, round, txs }: { payer: Payer; round: FinishedRound; txs: SettleTxs }) {
  return (
    <td>
      <SettleTxLink payer={payer} round={round} txs={txs} />
    </td>
  );
}

function SettleTxLink({ payer, round, txs }: { payer: Payer; round: FinishedRound; txs: SettleTxs }) {
  if (!isFinished(round.phase)) return <span className="round-muted">—</span>;
  const lookup = txs.data?.[round.id.toString()];
  if (txs.isError || lookup?.status === "failed") {
    return (
      <span className="round-muted">
        Lookup failed <button onClick={() => void txs.refetch()}>Retry</button>
      </span>
    );
  }
  if (!lookup) return <span className="round-muted">Looking up…</span>;
  const short = `${lookup.hash.slice(0, 8)}…${lookup.hash.slice(-6)}`;
  const label = lookup.kind === "refunded" ? `Refund tx ${short}` : short;
  const url = explorerTxUrl(payer.explorerUrl, lookup.hash);
  return url ? (
    <a href={url} target="_blank" rel="noopener noreferrer" title={lookup.hash}>
      {label}
      <span className="sr-only"> (opens block explorer)</span>
    </a>
  ) : (
    <code title={lookup.hash}>{label}</code>
  );
}

/** Shown under a Rounds table when the chain has no explorer, so plain hashes are not a mystery. */
export function NoExplorerNote({ payer }: { payer: Payer }) {
  if (payer.explorerUrl) return null;
  return (
    <p className="round-muted" data-testid="no-explorer-note">
      No block explorer is configured for this chain, so transaction hashes are shown as text.
    </p>
  );
}

type CopyStatus = "idle" | "copied" | "blocked";
const copyMessages: Record<CopyStatus, string> = {
  idle: "Discord has no share link, so copy it and paste into a channel.",
  copied: "Link copied. Paste it into Discord and it unfurls.",
  blocked: "Copy was blocked. Select the link above instead.",
};

/** Links that open exactly this Round on X and Telegram, plus a copyable link for Discord. */
function ShareBar({ payer, market, roundId }: { payer: Payer; market: Market; roundId?: bigint }) {
  const origin = useOrigin();
  const [copyStatus, setCopyStatus] = useState<CopyStatus>("idle");
  if (!origin || !roundId) return null;
  const url = roundUrl(origin, payer, market, roundId);
  const text = `${payer.name} Round #${roundId}: ${market === "updown" ? "up or down" : "above or below"} on $${payer.ticker}, settled onchain.`;
  const links = shareLinks(url, text);
  async function copyLink() {
    try {
      await navigator.clipboard.writeText(url);
      setCopyStatus("copied");
    } catch {
      setCopyStatus("blocked");
    }
  }
  return (
    <section className="round-share" aria-labelledby="round-share-title">
      <h2 id="round-share-title">Share Round #{String(roundId)}</h2>
      <div className="round-share-links">
        <a href={links.x} target="_blank" rel="noopener noreferrer">
          Share on X
        </a>
        <a href={links.telegram} target="_blank" rel="noopener noreferrer">
          Share on Telegram
        </a>
        <button onClick={() => void copyLink()}>Copy link for Discord</button>
      </div>
      <p className="round-share-url" data-testid="share-url">
        {url}
      </p>
      <p className="round-muted" role="status" aria-live="polite">
        {copyMessages[copyStatus]}
      </p>
    </section>
  );
}
