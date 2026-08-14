/**
 * Synthetic reading fixtures.
 *
 * We never see real patient data (SOW A.12.3) — synthetic fixtures are the
 * only debugging surface this project will ever have. The generator is
 * deterministic (seeded PRNG) and anchored to "now", so the demo never goes
 * stale, and it deliberately covers the awkward cases: duplicate readings
 * from two sources, skipped days, and mixed provenance.
 */

import type { BpReadingRow, BpTrendRow } from "@/lib/api/types";

/** mulberry32 — small deterministic PRNG, good enough for fixtures. */
export function mulberry32(seed: number): () => number {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const TZ = "Australia/Sydney";

export interface FixtureOptions {
  seed?: number;
  days?: number;
  now?: Date;
}

/**
 * 42 days of readings for persona "synthetic Alex": systolic drifting
 * 146 → 135, diastolic 92 → 86, 4–6 readings/week with skipped days,
 * ~70% HealthKit (Omron via Apple Health) / 30% manual, one deliberate
 * same-minute duplicate pair mid-series.
 */
export function buildSeedReadings(opts: FixtureOptions = {}): BpReadingRow[] {
  const { seed = 1337, days = 42, now = new Date() } = opts;
  const rand = mulberry32(seed);
  const rows: BpReadingRow[] = [];

  for (let daysAgo = days; daysAgo >= 0; daysAgo--) {
    // Skip ~30% of days — real people miss days.
    if (rand() < 0.3) continue;

    const progress = 1 - daysAgo / days; // 0 → 1 over the series
    const baseSys = 146 - 11 * progress;
    const baseDia = 92 - 6 * progress;
    const readingsToday = rand() < 0.35 ? 2 : 1;

    for (let i = 0; i < readingsToday; i++) {
      const morning = i === 0 ? rand() < 0.7 : false;
      const hour = morning ? 7 + Math.floor(rand() * 2) : 19 + Math.floor(rand() * 2);
      const t = new Date(now);
      t.setDate(t.getDate() - daysAgo);
      t.setHours(hour, Math.floor(rand() * 60), 0, 0);
      if (t > now) continue;

      const fromHealth = rand() < 0.7;
      rows.push({
        id: `fx-${daysAgo}-${i}`,
        effective_time: t.toISOString(),
        effective_tz: TZ,
        systolic: Math.round(baseSys + (rand() - 0.5) * 12),
        diastolic: Math.round(baseDia + (rand() - 0.5) * 8),
        source_type: fromHealth ? "healthkit" : "manual",
        source_name: fromHealth ? "OMRON connect" : null,
        body_site_display: rand() < 0.9 ? "Left arm" : "Right arm",
      });
    }
  }

  rows.sort((a, b) => a.effective_time.localeCompare(b.effective_time));
  return rows;
}

/**
 * Daily aggregate matching the `v_bp_trend` shape. In production this is
 * computed server-side; the mock derives it from the reading set so the two
 * stay consistent.
 */
export function aggregateTrend(readings: BpReadingRow[]): BpTrendRow[] {
  const byDay = new Map<string, BpReadingRow[]>();
  for (const r of readings) {
    const day = r.effective_time.slice(0, 10);
    const bucket = byDay.get(day) ?? [];
    bucket.push(r);
    byDay.set(day, bucket);
  }

  const round1 = (n: number) => Math.round(n * 10) / 10;
  return [...byDay.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([day, rs]) => {
      const sys = rs.map((r) => r.systolic);
      const dia = rs.map((r) => r.diastolic);
      const mean = (xs: number[]) => xs.reduce((a, b) => a + b, 0) / xs.length;
      return {
        day,
        min_systolic: Math.min(...sys),
        max_systolic: Math.max(...sys),
        mean_systolic: round1(mean(sys)),
        min_diastolic: Math.min(...dia),
        max_diastolic: Math.max(...dia),
        mean_diastolic: round1(mean(dia)),
        reading_count: rs.length,
      };
    });
}
