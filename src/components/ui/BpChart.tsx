import type { BpTrendRow } from "@/lib/api/types";

/**
 * Display-only trend chart (SOW Deliverable 6).
 *
 * Deliberately monochrome: ink-coloured marks only. No thresholds, colour
 * zones, bands, target ranges, or annotations that evaluate a value may be
 * added here — that is a contractual line (SOW A.3.3), not a style choice.
 * The chart shows daily mean systolic and diastolic exactly as recorded.
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
  const width = 340;
  const pad = { top: 16, right: 12, bottom: 28, left: 34 };

  if (rows.length === 0) return null;

  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;

  const values = rows.flatMap((r) => [r.mean_systolic, r.mean_diastolic]);
  const rawMin = Math.min(...values);
  const rawMax = Math.max(...values);
  const span = Math.max(rawMax - rawMin, 10);
  const yMin = Math.floor((rawMin - span * 0.15) / 10) * 10;
  const yMax = Math.ceil((rawMax + span * 0.15) / 10) * 10;

  const x = (i: number) =>
    pad.left + (rows.length === 1 ? innerW / 2 : (i / (rows.length - 1)) * innerW);
  const y = (v: number) => pad.top + innerH - ((v - yMin) / (yMax - yMin)) * innerH;

  const line = (pick: (r: BpTrendRow) => number) =>
    rows.map((r, i) => `${i === 0 ? "M" : "L"}${x(i).toFixed(1)},${y(pick(r)).toFixed(1)}`).join(" ");

  const yTicks = [yMin, Math.round((yMin + yMax) / 2), yMax];
  const first = rows[0];
  const last = rows[rows.length - 1];

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className="w-full"
      role="img"
      aria-label={ariaLabel}
    >
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

      {/* Systolic: solid ink line */}
      <path d={line((r) => r.mean_systolic)} fill="none" stroke="var(--app-chart-ink)" strokeWidth="1.8" />
      {/* Diastolic: dashed soft-ink line */}
      <path
        d={line((r) => r.mean_diastolic)}
        fill="none"
        stroke="var(--app-chart-ink-soft)"
        strokeWidth="1.6"
        strokeDasharray="4 4"
      />

      {rows.map((r, i) => (
        <g key={r.day}>
          <circle cx={x(i)} cy={y(r.mean_systolic)} r="2.4" fill="var(--app-chart-ink)" />
          <circle cx={x(i)} cy={y(r.mean_diastolic)} r="2.2" fill="var(--app-chart-ink-soft)" />
        </g>
      ))}

      {first && last ? (
        <>
          <text
            x={x(0)}
            y={height - 8}
            textAnchor="start"
            fontSize="10"
            fontFamily="var(--font-mono)"
            fill="var(--app-ink-tertiary)"
          >
            {new Date(`${first.day}T00:00:00`).toLocaleDateString("en-AU", { day: "numeric", month: "short" })}
          </text>
          <text
            x={x(rows.length - 1)}
            y={height - 8}
            textAnchor="end"
            fontSize="10"
            fontFamily="var(--font-mono)"
            fill="var(--app-ink-tertiary)"
          >
            {new Date(`${last.day}T00:00:00`).toLocaleDateString("en-AU", { day: "numeric", month: "short" })}
          </text>
        </>
      ) : null}
    </svg>
  );
}
