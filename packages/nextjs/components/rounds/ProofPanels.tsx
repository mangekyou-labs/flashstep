"use client";

import { useState } from "react";
import { Hash, formatUnits } from "viem";
import { Payer } from "~~/config/payers";
import {
  Market,
  embedSnippet,
  explorerTxUrl,
  roundUrl,
  shareLinks,
  useOrigin,
  usePoolBalance,
} from "~~/utils/rounds/proof";

/** Pool balance straight from the contract's own views; nothing is derived in the browser. */
export function PoolBalance({ payer, market }: { payer: Payer; market: Market }) {
  const pool = usePoolBalance(payer, market);
  const data = pool.data;
  const fmt = (value: bigint) => formatUnits(value, data?.decimals ?? 18);
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
              {fmt(data.funding + data.reserved)} {data.symbol}
            </strong>{" "}
            held by the contract to pay winners
          </p>
          <dl className="round-rules">
            <div>
              <dt>Committed to open Rounds</dt>
              <dd data-testid="pool-reserved">
                {fmt(data.reserved)} {data.symbol}
              </dd>
            </div>
            <div>
              <dt>Available for new Rounds</dt>
              <dd data-testid="pool-funding">
                {fmt(data.funding)} {data.symbol}
              </dd>
            </div>
          </dl>
        </>
      )}
    </section>
  );
}

/** Settle-transaction cell: a block-explorer link, or the short hash where the chain has no explorer. */
export function SettleTx({ payer, hash, settled }: { payer: Payer; hash?: Hash; settled: boolean }) {
  if (!settled) return <span className="round-muted">—</span>;
  if (!hash) return <span className="round-muted">Looking up…</span>;
  const short = `${hash.slice(0, 8)}…${hash.slice(-6)}`;
  const url = explorerTxUrl(payer.explorerUrl, hash);
  return url ? (
    <a href={url} target="_blank" rel="noopener noreferrer" title={hash}>
      {short}
      <span className="sr-only"> (opens block explorer)</span>
    </a>
  ) : (
    <code title={hash}>{short}</code>
  );
}

/** Links that open exactly this Round, plus a copyable iframe for the payer's site. */
export function ShareBar({ payer, market, roundId }: { payer: Payer; market: Market; roundId?: bigint }) {
  const origin = useOrigin();
  const [copied, setCopied] = useState("");
  if (!origin || !roundId) return null;
  const url = roundUrl(origin, payer, market, roundId);
  const text = `${payer.name} Round #${roundId}: ${market === "updown" ? "up or down" : "above or below"} on $${payer.ticker}, settled onchain.`;
  const links = shareLinks(url, text);
  async function copy(kind: string, value: string) {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(kind);
    } catch {
      setCopied("failed");
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
        <button onClick={() => void copy("discord", url)}>Copy link for Discord</button>
        <button onClick={() => void copy("embed", embedSnippet(url, `${payer.name} Rounds`))}>Copy embed code</button>
      </div>
      <p className="round-share-url" data-testid="share-url">
        {url}
      </p>
      <p className="round-muted" role="status" aria-live="polite">
        {copied === "failed"
          ? "Copy was blocked. Select the link above instead."
          : copied === "discord"
            ? "Link copied. Paste it into Discord and it unfurls."
            : copied === "embed"
              ? "Embed code copied."
              : "Discord has no share link, so copy it and paste into a channel."}
      </p>
    </section>
  );
}
