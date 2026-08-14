import { describe, expect, it } from "vitest";
import { aggregateTrend, buildSeedReadings } from "./fixtures";

describe("buildSeedReadings", () => {
  it("is deterministic for a fixed seed and date", () => {
    const now = new Date("2026-08-14T12:00:00Z");
    const a = buildSeedReadings({ seed: 1337, now });
    const b = buildSeedReadings({ seed: 1337, now });
    expect(a).toEqual(b);
    expect(a.length).toBeGreaterThan(20);
  });

  it("anchors to now, so the recent window is never empty", () => {
    const now = new Date();
    const rows = buildSeedReadings({ now });
    const fourteenDaysAgo = new Date(now);
    fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);
    const recent = rows.filter((r) => new Date(r.effective_time) >= fourteenDaysAgo);
    expect(recent.length).toBeGreaterThan(0);
  });

  it("mixes healthkit and manual provenance", () => {
    const rows = buildSeedReadings({ now: new Date("2026-08-14T12:00:00Z") });
    expect(rows.some((r) => r.source_type === "healthkit")).toBe(true);
    expect(rows.some((r) => r.source_type === "manual")).toBe(true);
  });
});

describe("aggregateTrend", () => {
  it("matches the v_bp_trend shape with one row per day", () => {
    const rows = buildSeedReadings({ now: new Date("2026-08-14T12:00:00Z") });
    const trend = aggregateTrend(rows);
    const days = new Set(trend.map((t) => t.day));
    expect(days.size).toBe(trend.length);
    for (const t of trend) {
      expect(t.min_systolic).toBeLessThanOrEqual(t.mean_systolic);
      expect(t.mean_systolic).toBeLessThanOrEqual(t.max_systolic);
      expect(t.reading_count).toBeGreaterThan(0);
    }
  });
});
