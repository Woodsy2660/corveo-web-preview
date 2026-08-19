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
 */
export function BpChart({
  rows,
  ariaLabel,
  height = 220,
}: {
  rows: BpTrendRow[];
  ariaLabel: string;
  height?: number;
}) {
  const gradientId = useId();
  const svgRef = useRef<SVGSVGElement>(null);
  const [active, setActive] = useState<number | null>(null);

  const width = 340;
  const pad = { top: 16, right: 12, bottom: 28, left: 34 };

  if (rows.length === 0) return null;

  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;
  const baseline = pad.top + innerH;

  const values = rows.flatMap((r) => [r.mean_systolic, r.mean_diastolic]);
  const rawMin = Math.min(...values);
  const rawMax = Math.max(...values);
  const span = Math.max(rawMax - rawMin, 10);
  const yMin = Math.floor((rawMin - span * 0.15) / 10) * 10;
  const yMax = Math.ceil((rawMax + span * 0.15) / 10) * 10;

  const x = (i: number) =>
    pad.left + (rows.length === 1 ? innerW / 2 : (i / (rows.length - 1)) * innerW);
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
  const xLabelIdx =
    rows.length >= 3 ? [0, Math.floor((rows.length - 1) / 2), rows.length - 1] : [0, rows.length - 1];
  const sparse = rows.length <= 2;
  const last = rows.length - 1;
  const lastRow = rows[last]!;

  const indexFromPointer = (e: ReactPointerEvent<SVGSVGElement>) => {
    const rect = svgRef.current?.getBoundingClientRect();
    if (!rect) return null;
    const mx = ((e.clientX - rect.left) / rect.width) * width;
    const i = Math.round(((mx - pad.left) / innerW) * (rows.length - 1));
    return Math.max(0, Math.min(rows.length - 1, i));
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
        </defs>

        {yTicks.map((t) => (
          <g key={t}>
            <line
              x1={pad.left}
              x2={width - pad.right}
              y1={y(t)}
              y2={y(t)}
              stroke="var(--app-hairline)"
              strokeWidth="1"
            />
            <text
              x={pad.left - 6}
              y={y(t) + 3}
              textAnchor="end"
              fontSize="10"
              fontFamily="var(--font-mono)"
              fill="var(--app-ink-tertiary)"
            >
              {t}
            </text>
          </g>
        ))}

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

      {activeRow ? (
        <div
          className="pointer-events-none absolute rounded-sm bg-action px-[var(--spacing-2xs)] py-[var(--spacing-3xs)] text-action-ink"
          style={{
            left: `${Math.max(18, Math.min(82, (x(active as number) / width) * 100))}%`,
            top: `${(Math.min(y(activeRow.mean_systolic), y(activeRow.mean_diastolic)) / height) * 100}%`,
            transform: "translate(-50%, calc(-100% - 8px))",
            fontSize: "var(--text-label)",
            lineHeight: "var(--leading-label)",
            whiteSpace: "nowrap",
          }}
        >
          <span className="block" style={{ color: "var(--color-text-secondary-inverse)" }}>
            {fmtDate(`${activeRow.day}T00:00:00`)}
          </span>
          <span style={{ fontFamily: "var(--font-mono)" }}>
            {activeRow.mean_systolic}/{activeRow.mean_diastolic} {APP.common.unitMmHg}
          </span>
        </div>
      ) : null}
    </div>
  );
}
