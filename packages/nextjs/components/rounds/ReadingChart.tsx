"use client";

import { useEffect, useState } from "react";
import { formatUnits } from "viem";

type Reading = { timestamp: bigint; price: bigint };
export function readingLabel(price?: bigint) {
  if (price === undefined) return "—";
  const value = Number(formatUnits(price, 36));
  return value.toLocaleString("en-US", { maximumSignificantDigits: 7 });
}

/** Samples only actual onchain TWAP views; chart geometry is display math, never settlement math. */
export function ReadingChart({
  reading,
  reference,
  roundId,
  ticker,
  quoteTicker,
}: {
  reading?: Reading;
  reference?: Reading;
  roundId: bigint;
  ticker: string;
  quoteTicker: string;
}) {
  const [points, setPoints] = useState<Reading[]>([]);
  useEffect(() => {
    setPoints([]);
  }, [roundId]);
  useEffect(() => {
    if (!reading) return;
    setPoints(previous =>
      previous.at(-1)?.timestamp === reading.timestamp ? previous : [...previous.slice(-119), reading],
    );
  }, [reading]);
  const guide = reference ?? points[0];
  const prices = [
    ...points.map(point => Number(formatUnits(point.price, 36))),
    ...(reference ? [Number(formatUnits(reference.price, 36))] : []),
  ];
  const low = Math.min(...prices);
  const high = Math.max(...prices);
  const span = Math.max(high - low, Math.abs(high) * 0.0002, 1e-30);
  const y = (price: bigint) => 180 - ((Number(formatUnits(price, 36)) - low) / span) * 140;
  const path = points
    .map(
      (point, index) => `${index ? "L" : "M"}${20 + (index / Math.max(points.length - 1, 1)) * 660},${y(point.price)}`,
    )
    .join(" ");
  return (
    <div className="round-chart">
      <div className="chart-caption">
        <span>
          Pool TWAP · {ticker}/{quoteTicker}
        </span>
        <strong>{readingLabel(reading?.price)}</strong>
      </div>
      {points.length ? (
        <svg
          viewBox="0 0 700 220"
          role="img"
          aria-label={`${ticker} pool TWAP chart. Latest ${readingLabel(reading?.price)} ${quoteTicker}. Dashed guide ${readingLabel(guide?.price)}.`}
        >
          {[40, 110, 180].map(value => (
            <line key={value} x1="20" x2="680" y1={value} y2={value} className="chart-grid" />
          ))}
          {guide && <line x1="20" x2="680" y1={y(guide.price)} y2={y(guide.price)} className="chart-reference" />}
          {points.length > 1 && <path d={path} className="chart-line" />}
          <circle cx={points.length > 1 ? 680 : 20} cy={y(points.at(-1)!.price)} r="4" className="chart-point" />
        </svg>
      ) : (
        <div className="chart-empty">Waiting for a pool Reading…</div>
      )}
      <div className="chart-caption">
        <span>Readings observed while this page is open</span>
        <span>
          {reference ? "Dashed line: start Reading" : "Dashed guide: first observed TWAP; start Reading pins at cutoff"}
        </span>
      </div>
    </div>
  );
}
