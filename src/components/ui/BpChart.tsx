import { useEffect, useRef, useState } from "react";
import type { PointerEvent as ReactPointerEvent } from "react";
import type { BpReadingRow } from "@/lib/api/types";
import { APP } from "@/copy/app";
import { fmtDate, fmtDateTime } from "@/lib/format";

/** Time-of-day filter for the chart. */
export type TimeFilter = "all" | "day" | "night";

/** Classify a reading as day (06:00–21:59) or night (22:00–05:59). */
function timeOfDay(isoTime: string): "day" | "night" {
  const h = new Date(isoTime).getHours();
  return h >= 6 && h < 22 ? "day" : "night";
}

/**
 * Display-only trend chart (SOW Deliverable 6).
 *
 * Plots raw individual readings as a connected line graph — no dots
 * at rest; dots appear only on the reading nearest the pointer/finger.
 * Series colours are fixed identities: systolic is always series-1,
 * diastolic always series-2.
 *
 * The scale sits in a gutter on the right, next to the newest point.
 */
export function BpChart({
  readings,
  ariaLabel,
  timeFilter = "all",
  width = 358,
  height = 260,
}: {
  readings: BpReadingRow[];
  ariaLabel: string;
  timeFilter?: TimeFilter;
  width?: number;
  height?: number;
}) {
  const svgRef = useRef<SVGSVGElement>(null);
  const lineRefs = useRef<(SVGPathElement | null)[]>([]);
  const hasDrawnOnce = useRef(false);
  const [active, setActive] = useState<number | null>(null);

  // Filter readings by time of day
  const filtered = timeFilter === "all"
    ? readings
    : readings.filter((r) => timeOfDay(r.effective_time) === timeFilter);

  // Sort readings oldest-first for plotting
  const sorted = [...filtered].sort(
    (a, b) => new Date(a.effective_time).getTime() - new Date(b.effective_time).getTime(),
  );

  // Line-draw animation on first mount only. On subsequent data changes
  // (range switch), clear the dash styles so the full path renders.
  useEffect(() => {
    const paths = lineRefs.current.filter(Boolean) as SVGPathElement[];
    if (paths.length === 0) return;

    if (hasDrawnOnce.current) {
      // Clear any dash styles left from the initial draw so the line
      // isn't clipped when the path gets longer on range switch.
      paths.forEach((p) => {
        p.style.strokeDasharray = "";
        p.style.strokeDashoffset = "";
        p.style.transition = "";
      });
      return;
    }

    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced) { hasDrawnOnce.current = true; return; }

    hasDrawnOnce.current = true;
    paths.forEach((p) => {
      const len = p.getTotalLength();
      p.style.strokeDasharray = `${len}`;
      p.style.strokeDashoffset = `${len}`;
      p.getBoundingClientRect();
      p.style.transition = `stroke-dashoffset 400ms cubic-bezier(0.16, 1, 0.3, 1)`;
      p.style.strokeDashoffset = "0";
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sorted.length, timeFilter]);

  // Tighter padding — data starts closer to the left edge
  const pad = { top: 16, right: 34, bottom: 28, left: 8 };

  if (sorted.length === 0) return null;

  const innerW = width - pad.left - pad.right;
  const innerH = height - pad.top - pad.bottom;
  const baseline = pad.top + innerH;
  const plotRight = width - pad.right;

  // Y-range from raw values
  const allValues = sorted.flatMap((r) => [r.systolic, r.diastolic]);
  const rawMin = Math.min(...allValues);
  const rawMax = Math.max(...allValues);
  const span = Math.max(rawMax - rawMin, 10);
  const yMin = Math.floor((rawMin - span * 0.15) / 10) * 10;
  const yMax = Math.ceil((rawMax + span * 0.15) / 10) * 10;

  const y = (v: number) => pad.top + innerH - ((v - yMin) / (yMax - yMin)) * innerH;

  // X positioning — always maps first reading to left edge, last reading
  // to right edge, so the line fills the full plot width on every filter.
  const tMin = new Date(sorted[0]!.effective_time).getTime();
  const tMax = new Date(sorted[sorted.length - 1]!.effective_time).getTime();
  const tSpan = Math.max(tMax - tMin, 1);
  const xOf = (isoTime: string) => {
    const t = new Date(isoTime).getTime();
    return pad.left + ((t - tMin) / tSpan) * innerW;
  };

  // Build polyline paths through raw readings
  const sysPath = sorted.map((r, i) => {
    const px = xOf(r.effective_time).toFixed(1);
    const py = y(r.systolic).toFixed(1);
    return i === 0 ? `M${px},${py}` : `L${px},${py}`;
  }).join("");

  const diaPath = sorted.map((r, i) => {
    const px = xOf(r.effective_time).toFixed(1);
    const py = y(r.diastolic).toFixed(1);
    return i === 0 ? `M${px},${py}` : `L${px},${py}`;
  }).join("");

  const series = [
    { key: "sys", color: "var(--app-chart-series-1)", path: sysPath, pick: (r: BpReadingRow) => r.systolic },
    { key: "dia", color: "var(--app-chart-series-2)", path: diaPath, pick: (r: BpReadingRow) => r.diastolic },
  ];

  // Averages
  const avgSys = Math.round(sorted.reduce((s, r) => s + r.systolic, 0) / sorted.length);
  const avgDia = Math.round(sorted.reduce((s, r) => s + r.diastolic, 0) / sorted.length);

  const yTicks = [yMin, Math.round((yMin + yMax) / 2), yMax];

  // Date labels — always show first and last reading dates
  const labelWidth = 50;
  const minGap = labelWidth + 8;
  let xLabels: { x: number; label: string; anchor: "start" | "middle" | "end" }[] = [];
  if (sorted.length > 0) {
    const f = { x: pad.left, label: fmtDate(sorted[0]!.effective_time), anchor: "start" as const };
    const l = { x: pad.left + innerW, label: fmtDate(sorted[sorted.length - 1]!.effective_time), anchor: "end" as const };
    xLabels = sorted.length <= 1 || innerW < minGap ? [l] : [f, l];
  }

  // Pointer interaction
  const readingFromPointer = (e: ReactPointerEvent<SVGSVGElement>) => {
    const rect = svgRef.current?.getBoundingClientRect();
    if (!rect || sorted.length === 0) return null;
    const mx = ((e.clientX - rect.left) / rect.width) * width;
    let best = 0;
    let bestDist = Infinity;
    for (let i = 0; i < sorted.length; i++) {
      const d = Math.abs(xOf(sorted[i]!.effective_time) - mx);
      if (d < bestDist) { bestDist = d; best = i; }
    }
    return best;
  };

  const activeReading = active !== null ? (sorted[active] ?? null) : null;

  return (
    <div className="relative">
      <svg
        ref={svgRef}
        viewBox={`0 0 ${width} ${height}`}
        className="w-full"
        role="img"
        aria-label={ariaLabel}
        style={{ touchAction: "pan-y" }}
        onPointerMove={(e) => setActive(readingFromPointer(e))}
        onPointerDown={(e) => setActive(readingFromPointer(e))}
        onPointerLeave={() => setActive(null)}
      >
        {/* Gridlines */}
        {yTicks.map((t) => (
          <g key={t}>
            <line x1={pad.left} x2={plotRight} y1={y(t)} y2={y(t)}
              stroke="var(--app-hairline)" strokeWidth="1" />
            <text x={plotRight + 6} y={y(t) + 3} textAnchor="start"
              fontSize="10" fontFamily="var(--font-mono)" fill="var(--app-ink-tertiary)">
              {t}
            </text>
          </g>
        ))}

        {/* Average dashed lines */}
        <g>
          <line x1={pad.left} x2={plotRight} y1={y(avgSys)} y2={y(avgSys)}
            stroke="var(--app-ink-tertiary)" strokeWidth="1" strokeDasharray="6 4" opacity="0.5" />
          <text x={plotRight + 6} y={y(avgSys) + 3} textAnchor="start"
            fontSize="9" fontFamily="var(--font-mono)" fill="var(--app-ink-tertiary)" opacity="0.7">
            {avgSys}
          </text>
          <line x1={pad.left} x2={plotRight} y1={y(avgDia)} y2={y(avgDia)}
            stroke="var(--app-ink-tertiary)" strokeWidth="1" strokeDasharray="6 4" opacity="0.5" />
          <text x={plotRight + 6} y={y(avgDia) + 3} textAnchor="start"
            fontSize="9" fontFamily="var(--font-mono)" fill="var(--app-ink-tertiary)" opacity="0.7">
            {avgDia}
          </text>
        </g>

        {/* Connected lines through raw readings */}
        {series.map((s, si) => (
          <path
            key={s.key}
            ref={(el) => { lineRefs.current[si] = el; }}
            d={s.path}
            fill="none"
            stroke={s.color}
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        ))}

        {/* Dots on hover/tap only */}
        {activeReading ? (
          <g>
            <line
              x1={xOf(activeReading.effective_time)}
              x2={xOf(activeReading.effective_time)}
              y1={pad.top} y2={baseline}
              stroke="var(--app-hairline)" strokeWidth="1"
            />
            {series.map((s) => (
              <circle
                key={s.key}
                cx={xOf(activeReading.effective_time)}
                cy={y(s.pick(activeReading))}
                r="4"
                fill={s.color}
                stroke="var(--app-card)"
                strokeWidth="1.5"
              />
            ))}
          </g>
        ) : null}

        {/* X-axis date labels */}
        {xLabels.map((l, n) => (
          <text key={n} x={l.x} y={height - 8}
            textAnchor={l.anchor}
            fontSize="10" fontFamily="var(--font-mono)" fill="var(--app-ink-tertiary)">
            {l.label}
          </text>
        ))}
      </svg>

      {/* Readout for the reading under the finger */}
      {activeReading ? (
        <div
          className="pointer-events-none absolute inset-x-0 flex justify-center gap-[var(--spacing-2xs)] text-ink-secondary"
          style={{
            top: `${((pad.top + 8) / height) * 100}%`,
            fontSize: "var(--text-body-sm)",
            lineHeight: "var(--leading-label)",
            whiteSpace: "nowrap",
          }}
        >
          <span className="text-ink-tertiary">{fmtDateTime(activeReading.effective_time)}</span>
          <span className="text-heading" style={{ fontWeight: 500 }}>
            {activeReading.systolic}/{activeReading.diastolic}
          </span>
          <span className="text-ink-tertiary">{APP.common.unitMmHg}</span>
        </div>
      ) : null}
    </div>
  );
}
