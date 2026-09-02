import { useId, useRef, useState } from "react";
import type { PointerEvent as ReactPointerEvent } from "react";
import type { BpTrendRow } from "@/lib/api/types";
import { APP } from "@/copy/app";
import { fmtDate } from "@/lib/format";

/**
 * Display-only trend chart (SOW Deliverable 6).
 *
 * Gradient area treatment, two series overlaid (never stacked — systolic and
 * diastolic are independent measures on one scale; stacking would plot their
 * sum). Series colours are fixed identities: systolic is always series-1,
 * diastolic always series-2. No thresholds, colour zones, bands, target
 * ranges, or annotations that evaluate a value may be added here — that is a
 * contractual line (SOW A.3.3), not a style choice. The chart and its
 * tooltip show daily mean systolic and diastolic exactly as recorded.
 *
 * The scale sits in a gutter on the right, next to the newest point. The
 * first `leadCount` rows are the days before the chosen period: they sit in
 * a narrow strip at the left, faded, so the line arrives smoothly and the
 * unfaded plot is exactly the period picked. With no lead rows (All) the
 * line starts at the left margin.
 */
export function BpChart({
  rows,
  leadCount = 0,
  ariaLabel,
  width = 340,
  height = 220,
}: {
  rows: BpTrendRow[];
  leadCount?: number;
  ariaLabel: string;
  width?: number;
  height?: number;
}) {
  const gradientId = useId();
  const svgRef = useRef<SVGSVGElement>(null);
  const [active, setActive] = useState<number | null>(null);

  const leadIn = leadCount > 0 && leadCount < rows.length;
  const leftInset = 16; // Left margin so chart doesn't touch edge
  const plotLeft = 24; // Fixed left edge of plot area - consistent across all ranges
  const pad = { top: 16, right: 36, bottom: 28, left: plotLeft };

  if (rows.length === 0) return null;

  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;
  const baseline = pad.top + innerH;
  const plotRight = width - pad.right;
  const first = leadIn ? leadCount : 0;
  const periodN = rows.length - first;

  const values = rows.flatMap((r) => [r.mean_systolic, r.mean_diastolic]);
  const rawMin = Math.min(...values);
  const rawMax = Math.max(...values);
  const span = Math.max(rawMax - rawMin, 10);
  const yMin = Math.floor((rawMin - span * 0.15) / 10) * 10;
  const yMax = Math.ceil((rawMax + span * 0.15) / 10) * 10;

  // All data points share the same plot area for consistent positioning across ranges.
  // Lead-in rows (if any) are included in the data but drawn with a fade mask.
  const totalPoints = rows.length;
  const x = (i: number) =>
    pad.left + (totalPoints === 1 ? innerW / 2 : (i / (totalPoints - 1)) * innerW);
  const y = (v: number) => pad.top + innerH - ((v - yMin) / (yMax - yMin)) * innerH;

  /* Catmull-Rom through the points, emitted as cubic beziers — the same
   * "natural" curve as the reference treatment. */
  const smoothPath = (pick: (r: BpTrendRow) => number) => {
    const pts = rows.map((r, i) => ({ px: x(i), py: y(pick(r)) }));
    const at = (i: number) => pts[Math.max(0, Math.min(pts.length - 1, i))]!;
    let d = `M${at(0).px.toFixed(1)},${at(0).py.toFixed(1)}`;
    for (let i = 0; i < pts.length - 1; i++) {
      const p0 = at(i - 1);
      const p1 = at(i);
      const p2 = at(i + 1);
      const p3 = at(i + 2);
      const c1x = p1.px + (p2.px - p0.px) / 6;
      const c1y = p1.py + (p2.py - p0.py) / 6;
      const c2x = p2.px - (p3.px - p1.px) / 6;
      const c2y = p2.py - (p3.py - p1.py) / 6;
      d += `C${c1x.toFixed(1)},${c1y.toFixed(1)} ${c2x.toFixed(1)},${c2y.toFixed(1)} ${p2.px.toFixed(1)},${p2.py.toFixed(1)}`;
    }
    return d;
  };

  const series = [
    { key: "sys", color: "var(--app-chart-series-1)", pick: (r: BpTrendRow) => r.mean_systolic },
    { key: "dia", color: "var(--app-chart-series-2)", pick: (r: BpTrendRow) => r.mean_diastolic },
  ];

  const yTicks = [yMin, Math.round((yMin + yMax) / 2), yMax];
  const lastI = rows.length - 1;

  // Calculate which date labels to show. Avoid overlap by checking pixel
  // distance between labels — date text is roughly 45px wide at font-size 10.
  const firstX = x(0);
  const lastX = x(lastI);
  const labelWidth = 50; // Approximate width of a date label
  const minGap = labelWidth + 8; // Minimum pixels between label centers

  // Only show distinct labels — if there's only one point, show one label.
  // If the gap between first and last is too small, only show last (newest).
  // Otherwise show first and last; add middle only if there's room for all three.
  let xLabelIdx: number[];
  if (totalPoints <= 1) {
    // Single data point: show just one label
    xLabelIdx = [lastI];
  } else if (lastX - firstX < minGap) {
    // Not enough room for two labels: show just the most recent
    xLabelIdx = [lastI];
  } else {
    // Room for at least two labels; check if we can fit a middle one
    const midIdx = Math.floor(lastI / 2);
    const midX = x(midIdx);
    const showMiddle = totalPoints >= 3 && midIdx !== 0 && midIdx !== lastI &&
      (midX - firstX) >= minGap && (lastX - midX) >= minGap;
    xLabelIdx = showMiddle ? [0, midIdx, lastI] : [0, lastI];
  }

  const sparse = rows.length <= 2;
  const last = rows.length - 1;
  const lastRow = rows[last]!;

  const indexFromPointer = (e: ReactPointerEvent<SVGSVGElement>) => {
    const rect = svgRef.current?.getBoundingClientRect();
    if (!rect) return null;
    const mx = ((e.clientX - rect.left) / rect.width) * width;
    const i = Math.round(((mx - pad.left) / innerW) * (totalPoints - 1));
    return Math.max(0, Math.min(lastI, i));
  };

  const activeRow = active === null ? null : (rows[active] ?? null);

  return (
    <div className="relative">
      <svg
        ref={svgRef}
        viewBox={`0 0 ${width} ${height}`}
        className="w-full"
        role="img"
        aria-label={ariaLabel}
        style={{ touchAction: "pan-y" }}
        onPointerMove={(e) => setActive(indexFromPointer(e))}
        onPointerDown={(e) => setActive(indexFromPointer(e))}
        onPointerLeave={() => setActive(null)}
      >
        <defs>
          {series.map((s) => (
            <linearGradient key={s.key} id={`${gradientId}-${s.key}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={s.color} stopOpacity="0.32" />
              <stop offset="95%" stopColor={s.color} stopOpacity="0.04" />
            </linearGradient>
          ))}
          {leadIn ? (() => {
            // Fade mask covers from plot start to the first period point
            const fadeEnd = x(first);
            return (
              <>
                <linearGradient id={`${gradientId}-lead`} gradientUnits="userSpaceOnUse" x1={pad.left} y1="0" x2={fadeEnd} y2="0">
                  <stop offset="0" stopColor="#fff" stopOpacity="0.2" />
                  <stop offset="1" stopColor="#fff" stopOpacity="1" />
                </linearGradient>
                <mask id={`${gradientId}-mask`} maskUnits="userSpaceOnUse" x="0" y="0" width={width} height={height}>
                  <rect x={pad.left} y="0" width={fadeEnd - pad.left} height={height} fill={`url(#${gradientId}-lead)`} />
                  <rect x={fadeEnd} y="0" width={width - fadeEnd} height={height} fill="#fff" />
                </mask>
              </>
            );
          })() : null}
        </defs>

        {yTicks.map((t) => (
          <g key={t}>
            <line
              x1={leftInset}
              x2={plotRight}
              y1={y(t)}
              y2={y(t)}
              stroke="var(--app-hairline)"
              strokeWidth="1"
            />
            <text
              x={plotRight + 8}
              y={y(t) + 3}
              textAnchor="start"
              fontSize="10"
              fontFamily="var(--font-mono)"
              fill="var(--app-ink-tertiary)"
            >
              {t}
            </text>
          </g>
        ))}

        <g mask={leadIn ? `url(#${gradientId}-mask)` : undefined}>
        {series.map((s) =>
          sparse ? (
            <g key={s.key}>
              {rows.map((r, i) => (
                <circle key={r.day} cx={x(i)} cy={y(s.pick(r))} r="3.2" fill={s.color} />
              ))}
            </g>
          ) : (
            <g key={s.key}>
              <path
                d={`${smoothPath(s.pick)}L${x(last).toFixed(1)},${baseline}L${x(0).toFixed(1)},${baseline}Z`}
                fill={`url(#${gradientId}-${s.key})`}
              />
              <path
                d={smoothPath(s.pick)}
                fill="none"
                stroke={s.color}
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
              <circle
                cx={x(last)}
                cy={y(s.pick(lastRow))}
                r="3.2"
                fill={s.color}
                stroke="var(--app-card)"
                strokeWidth="1.5"
              />
            </g>
          ),
        )}
        </g>

        {active !== null && activeRow ? (
          <g>
            <line
              x1={x(active)}
              x2={x(active)}
              y1={pad.top}
              y2={baseline}
              stroke="var(--app-hairline)"
              strokeWidth="1"
            />
            {series.map((s) => (
              <circle
                key={s.key}
                cx={x(active)}
                cy={y(s.pick(activeRow))}
                r="3.4"
                fill={s.color}
                stroke="var(--app-card)"
                strokeWidth="1.5"
              />
            ))}
          </g>
        ) : null}

        {xLabelIdx.map((i, n) => {
          const row = rows[i];
          if (!row) return null;
          return (
            <text
              key={row.day}
              x={x(i)}
              y={height - 8}
              textAnchor={n === 0 ? "start" : n === xLabelIdx.length - 1 ? "end" : "middle"}
              fontSize="10"
              fontFamily="var(--font-mono)"
              fill="var(--app-ink-tertiary)"
            >
              {fmtDate(`${row.day}T00:00:00`)}
            </text>
          );
        })}
      </svg>

      {/* Readout for the day under the finger: one fixed line just inside
          the top of the plot rather than a box chasing the point, so the
          chart stays readable while the finger moves. Mean of that day,
          rounded. */}
      {activeRow ? (
        <div
          className="pointer-events-none absolute inset-x-0 flex justify-center gap-[var(--spacing-2xs)] text-ink-secondary"
          style={{
            top: `${((pad.top + 8) / height) * 100}%`,
            fontSize: "var(--text-body-sm)",
            lineHeight: "var(--leading-label)",
            whiteSpace: "nowrap",
          }}
        >
          <span className="text-ink-tertiary">{fmtDate(`${activeRow.day}T00:00:00`)}</span>
          <span className="text-heading" style={{ fontWeight: 500 }}>
            {Math.round(activeRow.mean_systolic)}/{Math.round(activeRow.mean_diastolic)}
          </span>
          <span className="text-ink-tertiary">{APP.common.unitMmHg}</span>
        </div>
      ) : null}
    </div>
  );
}
