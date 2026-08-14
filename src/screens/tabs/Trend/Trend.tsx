import { useState } from "react";
import { Link } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Segmented } from "@/components/ui/Segmented";
import { BpChart } from "@/components/ui/BpChart";
import { APP } from "@/copy/app";
import { useTrend } from "@/lib/api/hooks";
import { dayNDaysAgo } from "@/lib/format";

type Range = "2w" | "6w" | "all";

const RANGE_DAYS: Record<Range, number | null> = { "2w": 14, "6w": 42, all: null };

/**
 * Trend tab (Deliverable 6) — display-only. Daily aggregates exactly as
 * recorded; no thresholds, zones, bands, or alerts, by contract.
 */
export function Trend() {
  const [range, setRange] = useState<Range>("6w");
  const days = RANGE_DAYS[range];
  const { data: rows, isLoading } = useTrend(days ? dayNDaysAgo(days) : undefined);
  const c = APP.trend;

  return (
    <Screen
      eyebrow={c.eyebrow}
      title={c.title}
      withTabBar
      action={
        <Link to="/app/settings" className="eyebrow underline underline-offset-4">
          {APP.common.settingsLink}
        </Link>
      }
    >
      <p className="pb-[var(--spacing-sm)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
        {c.intro}
      </p>

      <div className="pb-[var(--spacing-sm)]">
        <Segmented
          ariaLabel={c.rangeAria}
          value={range}
          onChange={setRange}
          options={[
            { value: "2w", label: c.ranges.twoWeeks },
            { value: "6w", label: c.ranges.sixWeeks },
            { value: "all", label: c.ranges.all },
          ]}
        />
      </div>

      <Card>
        {isLoading ? null : !rows || rows.length === 0 ? (
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {c.empty}
          </p>
        ) : (
          <>
            <BpChart rows={rows} ariaLabel={c.chartAria} />
            <div className="flex gap-[var(--spacing-sm)] pt-[var(--spacing-2xs)]">
              <span className="flex items-center gap-[var(--spacing-3xs)] text-ink-secondary" style={{ fontSize: "12px" }}>
                <span className="inline-block h-[2px] w-[16px] bg-chart-ink" />
                {c.legendSystolic}
              </span>
              <span className="flex items-center gap-[var(--spacing-3xs)] text-ink-secondary" style={{ fontSize: "12px" }}>
                <span
                  className="inline-block h-[2px] w-[16px]"
                  style={{
                    backgroundImage:
                      "linear-gradient(to right, var(--app-chart-ink-soft) 60%, transparent 40%)",
                    backgroundSize: "6px 2px",
                  }}
                />
                {c.legendDiastolic}
              </span>
            </div>
          </>
        )}
      </Card>
    </Screen>
  );
}
