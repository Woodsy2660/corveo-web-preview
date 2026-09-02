import { useState } from "react";
import { useNavigate } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { CheckIcon, PlusIcon, SyncIcon } from "@/components/ui/icons";
import { Segmented } from "@/components/ui/Segmented";
import { BpChart } from "@/components/ui/BpChart";
import { APP } from "@/copy/app";
import { HEALTH_SYNC } from "@/copy/health-sync";
import { useReadings, useTrend } from "@/lib/api/hooks";
import { useAppleHealthSync } from "@/lib/health/useAppleHealthSync";
import { dayNDaysAgo, fmtDateTime } from "@/lib/format";
import type { BpTrendRow } from "@/lib/api/types";

type Range = "1w" | "6w" | "all";

const RANGE_DAYS: Record<Range, number | null> = { "1w": 7, "6w": 42, all: null };
/** Days before the period that show faded at the chart's edge, so the line arrives rather than starts. */
const LEAD_DAYS: Record<Range, number> = { "1w": 2, "6w": 7, all: 0 };

/** Full screen width: the chart bleeds past the page padding on both sides. */
const CHART_WIDTH = 393;
const CHART_HEIGHT = 250;

/** Mean of the readings behind the daily rows, weighted by how many each day holds. */
function periodAverage(rows: BpTrendRow[]): { systolic: number; diastolic: number } | null {
  const n = rows.reduce((sum, r) => sum + r.reading_count, 0);
  if (n === 0) return null;
  const sys = rows.reduce((sum, r) => sum + r.mean_systolic * r.reading_count, 0) / n;
  const dia = rows.reduce((sum, r) => sum + r.mean_diastolic * r.reading_count, 0) / n;
  return { systolic: Math.round(sys), diastolic: Math.round(dia) };
}

/**
 * My Heart Record (Deliverables 4 and 6) — the trend and the history on one
 * screen. They are the same data at two grains; the chart summarises the
 * list and the list is the chart's detail.
 *
 * Both remain display-only. The average over the chosen period is a plain
 * mean of the readings on screen — a summary, never a threshold or a
 * target, and it draws nothing on the chart. The chart has no zones, bands
 * or annotations; its two colours are fixed series identities. The list
 * shows readings exactly as recorded.
 */
export function Record() {
  const navigate = useNavigate();
  const [range, setRange] = useState<Range>("1w");
  const [showAll, setShowAll] = useState(false);
  const days = RANGE_DAYS[range];
  const since = days ? dayNDaysAgo(days) : undefined;
  const fetchSince = days ? dayNDaysAgo(days + LEAD_DAYS[range]) : undefined;

  const { data: fetched, isLoading: trendLoading } = useTrend(fetchSince);
  // Daily rows arrive oldest first; the lead is whatever falls before the period.
  const rows = fetched ?? [];
  const periodRows = since ? rows.filter((row) => row.day >= since) : rows;
  const leadCount = rows.length - periodRows.length;
  const { data: readings, isLoading: readingsLoading } = useReadings(30);
  const health = useAppleHealthSync();

  const c = APP.record;
  const r = APP.readings;
  const t = APP.trend;

  const average = periodAverage(periodRows);
  const chartEmpty = periodRows.length === 0;

  return (
    <Screen title={c.title} withTabBar action={<ProfileLink />}>
      {/* — Average for the period on screen. The block keeps its height while
          the readings load, so nothing beneath it hops when they land. — */}
      <div
        className="pb-[var(--spacing-sm)]"
        style={{ visibility: average ? "visible" : "hidden" }}
        aria-hidden={!average}
      >
        <p className="eyebrow pb-[var(--spacing-3xs)]">{t.averageLabel[range]}</p>
        <p
          className="font-display text-heading"
          style={{ fontSize: "var(--text-special-lg)", lineHeight: "var(--leading-special)" }}
        >
          {average?.systolic ?? "\u2013"}
          <span className="text-ink-tertiary"> / </span>
          {average?.diastolic ?? "\u2013"}
          <span
            className="pl-[var(--spacing-2xs)] font-body text-ink-tertiary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {APP.common.unitMmHg}
          </span>
        </p>
      </div>

      {/* — Period, above the chart: outlined pills, flush with the number. — */}
      <div className="pb-[var(--spacing-xs)]">
        <Segmented
          ariaLabel={t.rangeAria}
          value={range}
          onChange={setRange}
          options={[
            { value: "1w", label: t.ranges.oneWeek },
            { value: "6w", label: t.ranges.sixWeeks },
            { value: "all", label: t.ranges.all },
          ]}
        />
      </div>

      {/* — Chart — no card: it bleeds past the page padding on both sides,
          the scale in a gutter on the right by the newest point. The days
          before the period sit faded at the left edge, so the unfaded plot
          is exactly the period chosen; on All nothing comes before. */}
      {trendLoading ? (
        <div style={{ height: CHART_HEIGHT }} aria-hidden />
      ) : chartEmpty ? (
        <Card>
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {t.empty}
          </p>
        </Card>
      ) : (
        <div className="-mx-[var(--spacing-md)]">
          <BpChart
            rows={rows}
            leadCount={leadCount}
            ariaLabel={t.chartAria}
            width={CHART_WIDTH}
            height={CHART_HEIGHT}
          />
        </div>
      )}

      {/* — Legend, under the chart, left, quiet — */}
      <div
        className="flex gap-[var(--spacing-md)] pt-[var(--spacing-xs)] text-ink-tertiary"
        style={{ fontSize: "var(--text-label)" }}
      >
        <span className="flex items-center gap-[var(--spacing-3xs)]">
          <span className="inline-block size-[8px] rounded-round bg-chart-series-1" />
          {t.legendSystolic}
        </span>
        <span className="flex items-center gap-[var(--spacing-3xs)]">
          <span className="inline-block size-[8px] rounded-round bg-chart-series-2" />
          {t.legendDiastolic}
        </span>
      </div>

      <div className="pt-[var(--spacing-sm)]">
        <Button variant="secondary" onClick={() => navigate("/app/add")}>
          <span className="inline-flex items-center gap-[var(--spacing-2xs)]">
            <PlusIcon />
            {r.addCta}
          </span>
        </Button>
      </div>

      <p className="pt-[var(--spacing-sm)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
        {t.intro}
      </p>

      {/* — History — with the Apple Health check in its heading row: when the
          app last looked, and a way to look now. Health users only. */}
      <div className="flex items-end justify-between pt-[var(--spacing-lg)] pb-[var(--spacing-2xs)]">
        <h2 style={{ fontSize: "var(--text-heading-xl)" }}>{c.historyHeading}</h2>
        {health.active ? (
          <div className="flex items-center gap-[var(--spacing-2xs)]">
            <span
              aria-live="polite"
              style={{
                fontSize: "var(--text-body-sm)",
                color: health.arrived ? "var(--color-surface-color-1)" : "var(--app-ink-tertiary)",
                transition: "color var(--duration-base) var(--ease-brand)",
              }}
            >
              {health.status}
            </span>
            <button
              onClick={health.sync}
              disabled={health.phase === "busy"}
              aria-label={HEALTH_SYNC.card.sync.aria}
              className="inline-flex flex-none items-center gap-[var(--spacing-3xs)] rounded-round border border-hairline px-[var(--spacing-xs)] py-[var(--spacing-3xs)] active:opacity-70 disabled:opacity-70"
              style={{
                fontSize: "var(--text-body-sm)",
                lineHeight: "var(--leading-label)",
                fontWeight: 500,
                color: health.phase === "done" ? "var(--color-surface-color-1)" : "var(--app-heading)",
                borderColor: health.phase === "done" ? "var(--color-surface-color-1)" : undefined,
                transitionProperty: "color, border-color, opacity",
                transitionDuration: "var(--duration-base)",
                transitionTimingFunction: "var(--ease-brand)",
              }}
            >
              <span
                className={`flex size-[13px] items-center justify-center ${health.phase === "busy" ? "spin" : ""}`}
              >
                {health.phase === "done" ? <CheckIcon /> : <SyncIcon />}
              </span>
              {health.label}
            </button>
          </div>
        ) : null}
      </div>

      {readingsLoading ? null : !readings || readings.length === 0 ? (
        <Card>
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {r.empty}
          </p>
        </Card>
      ) : (
        <>
          {readings.length < 8 ? (
            <p className="pb-[var(--spacing-xs)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
              {r.sparse}
            </p>
          ) : null}
          {/* Quiet rows on the page ground, a hairline between: the record is
              a list, not a stack of cards. */}
          <ul className="flex flex-col">
            {(showAll ? readings : readings.slice(0, 3)).map((reading) => (
              <li
                key={reading.id}
                className="flex items-baseline justify-between gap-[var(--spacing-sm)] border-b border-hairline py-[var(--spacing-xs)]"
              >
                <div className="flex items-baseline gap-[var(--spacing-2xs)]">
                  <span style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}>
                    {reading.systolic}/{reading.diastolic}
                  </span>
                  <span className="text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
                    {APP.common.unitMmHg}
                  </span>
                </div>
                <div
                  className="flex flex-1 items-baseline justify-end gap-[var(--spacing-2xs)] text-right text-ink-tertiary"
                  style={{ fontSize: "var(--text-body-sm)" }}
                >
                  <span>{fmtDateTime(reading.effective_time)}</span>
                  <span aria-hidden>·</span>
                  <span>
                    {reading.source_type === "healthkit" ? r.sourceHealth : r.sourceManual}
                    {/* Most readings are left-arm; only flag the exception. */}
                    {reading.body_site_display && reading.body_site_display !== "Left arm"
                      ? `, ${reading.body_site_display.toLowerCase()}`
                      : null}
                  </span>
                </div>
              </li>
            ))}
          </ul>
          {readings.length > 3 ? (
            <Button
              variant="ghost"
              className="mt-[var(--spacing-2xs)]"
              onClick={() => setShowAll((v) => !v)}
              aria-expanded={showAll}
            >
              {showAll ? r.showFewer : r.showAll}
            </Button>
          ) : null}
        </>
      )}
    </Screen>
  );
}
