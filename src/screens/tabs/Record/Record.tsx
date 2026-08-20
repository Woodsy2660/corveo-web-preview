import { useState } from "react";
import { useNavigate } from "react-router";
import { Screen, ProfileLink } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Chip } from "@/components/ui/Chip";
import { PlusIcon } from "@/components/ui/icons";
import { Segmented } from "@/components/ui/Segmented";
import { BpChart } from "@/components/ui/BpChart";
import { AppleHealthCard } from "@/components/ui/AppleHealthCard";
import { APP } from "@/copy/app";
import { useReadings, useTrend } from "@/lib/api/hooks";
import { dayNDaysAgo, fmtDateTime } from "@/lib/format";

type Range = "2w" | "6w" | "all";

const RANGE_DAYS: Record<Range, number | null> = { "2w": 14, "6w": 42, all: null };

/**
 * My Heart Record (Deliverables 4 and 6) — the trend and the history on one
 * screen. They are the same data at two grains; the chart summarises the
 * list and the list is the chart's detail.
 *
 * Both remain display-only. Merging their presentation changes nothing about
 * that: the chart has no thresholds, zones, bands or annotations — its two
 * colours are fixed series identities (systolic/diastolic), never value-
 * mapped — and the list still shows readings exactly as recorded. The two
 * deliverables are still demonstrated independently against the Stage 2 and
 * Stage 3 test scripts.
 */
export function Record() {
  const navigate = useNavigate();
  const [range, setRange] = useState<Range>("6w");
  const days = RANGE_DAYS[range];

  const { data: rows, isLoading: trendLoading } = useTrend(
    days ? dayNDaysAgo(days) : undefined,
  );
  const { data: readings, isLoading: readingsLoading } = useReadings(30);

  const c = APP.record;
  const r = APP.readings;
  const t = APP.trend;

  return (
    <Screen title={c.title} withTabBar action={<ProfileLink />}>
      {/* Apple Health status — renders only once authorisation was requested. */}
      <AppleHealthCard />

      {/* — Pattern — the screen title heads this section directly; a second
          heading stacked under it read as a double header. */}
      <p
        className="pb-[var(--spacing-sm)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {t.intro}
      </p>

      {/*
       * Range picker and the add action share a row: the primary write
       * action sits at the far right of the chart's own controls rather
       * than as a full-width button pushing the record down the screen.
       */}
      <div className="flex items-center justify-between pb-[var(--spacing-sm)]">
        <Segmented
          ariaLabel={t.rangeAria}
          value={range}
          onChange={setRange}
          options={[
            { value: "2w", label: t.ranges.twoWeeks },
            { value: "6w", label: t.ranges.sixWeeks },
            { value: "all", label: t.ranges.all },
          ]}
        />
        {/* 40px mark inside a 44px hit area, so it sits comfortably beside
            the 35px range control without dropping below the touch minimum. */}
        <button
          onClick={() => navigate("/app/add")}
          aria-label={r.addCta}
          title={r.addCta}
          className="-mr-[2px] flex size-[44px] items-center justify-center active:opacity-80"
          style={{
            transitionProperty: "opacity",
            transitionDuration: "var(--duration-fast)",
            transitionTimingFunction: "var(--ease-brand)",
          }}
        >
          <span
            className="flex size-[40px] items-center justify-center rounded-round bg-action text-action-ink"
            style={{ fontSize: "var(--text-body-lg)" }}
          >
            <PlusIcon />
          </span>
        </button>
      </div>

      <Card>
        {trendLoading ? null : !rows || rows.length === 0 ? (
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {t.empty}
          </p>
        ) : (
          <>
            <BpChart rows={rows} ariaLabel={t.chartAria} />
            <div className="flex gap-[var(--spacing-sm)] pt-[var(--spacing-2xs)]">
              <span
                className="flex items-center gap-[var(--spacing-3xs)] text-ink-secondary"
                style={{ fontSize: "var(--text-label)" }}
              >
                <span className="inline-block size-[10px] rounded-xs bg-chart-series-1" />
                {t.legendSystolic}
              </span>
              <span
                className="flex items-center gap-[var(--spacing-3xs)] text-ink-secondary"
                style={{ fontSize: "var(--text-label)" }}
              >
                <span className="inline-block size-[10px] rounded-xs bg-chart-series-2" />
                {t.legendDiastolic}
              </span>
            </div>
          </>
        )}
      </Card>

      {/* — History — */}
      <h2
        className="pt-[var(--spacing-lg)] pb-[var(--spacing-2xs)]"
        style={{ fontSize: "var(--text-heading-xl)" }}
      >
        {c.historyHeading}
      </h2>

      {readingsLoading ? null : !readings || readings.length === 0 ? (
        <Card>
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {r.empty}
          </p>
        </Card>
      ) : (
        <>
          {readings.length < 8 ? (
            <p
              className="pb-[var(--spacing-xs)] text-ink-tertiary"
              style={{ fontSize: "var(--text-body-sm)" }}
            >
              {r.sparse}
            </p>
          ) : null}
          <ul className="flex flex-col gap-[var(--spacing-2xs)]">
            {readings.map((reading) => (
              <li
                key={reading.id}
                className="flex items-center justify-between rounded-md bg-card px-[var(--spacing-sm)] py-[var(--spacing-xs)]"
              >
                <div>
                  <span style={{ fontSize: "var(--text-body-lg)", fontWeight: 500 }}>
                    {reading.systolic}/{reading.diastolic}
                  </span>
                  <span
                    className="pl-[var(--spacing-2xs)] text-ink-tertiary"
                    style={{ fontSize: "var(--text-body-sm)" }}
                  >
                    {APP.common.unitMmHg}
                  </span>
                  <span
                    className="block text-ink-tertiary"
                    style={{ fontSize: "var(--text-body-sm)" }}
                  >
                    {fmtDateTime(reading.effective_time)}
                  </span>
                </div>
                <div className="flex flex-col items-end gap-[var(--spacing-3xs)]">
                  <Chip>
                    {reading.source_type === "healthkit" ? r.sourceHealth : r.sourceManual}
                  </Chip>
                  {/* Most readings are left-arm; only flag the exception. */}
                  {reading.body_site_display && reading.body_site_display !== "Left arm" ? (
                    <Chip>{reading.body_site_display}</Chip>
                  ) : null}
                </div>
              </li>
            ))}
          </ul>
        </>
      )}
    </Screen>
  );
}
