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
import { localDay } from "@/lib/format";

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
 * 42 days of readings for persona "synthetic Alex": stable baseline around
 * 138/87 with natural variation, 4–6 readings/week with skipped days,
 * ~70% HealthKit (Omron via Apple Health) / 30% manual.
 *
 * Deliberately NO systematic downward drift: a demo dataset that "improves"
 * over the program would visually imply the program lowers blood pressure —
 * an outcome claim the IPS prohibits. The demo shows tracking, not results.
 */
export function buildSeedReadings(opts: FixtureOptions = {}): BpReadingRow[] {
  const { seed = 1337, days = 42, now = new Date() } = opts;
  const rand = mulberry32(seed);
  const rows: BpReadingRow[] = [];

  for (let daysAgo = days; daysAgo >= 0; daysAgo--) {
    // Skip ~30% of days — real people miss days.
    if (rand() < 0.3) continue;

    const baseSys = 138;
    const baseDia = 87;
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
        // HealthKit has no field for the cuff arm (docs/02 §body_site): only
        // hand-entered readings carry one.
        body_site_display: fromHealth ? null : rand() < 0.9 ? "Left arm" : "Right arm",
      });
    }
  }

  // One deliberate near-duplicate mid-series: the same reading arriving from
  // both the cuff app (via Apple Health) and a manual entry in the same
  // minute — the awkward two-source case the record has to display honestly.
  const mid = rows[Math.floor(rows.length / 2)];
  if (mid) {
    rows.push({
      ...mid,
      id: `${mid.id}-manual-dup`,
      source_type: "manual",
      source_name: null,
    });
  }

  rows.sort((a, b) => a.effective_time.localeCompare(b.effective_time));
  return rows;
}

/**
 * Daily aggregate matching the `v_bp_trend` shape. In production this is
 * computed server-side; the mock derives it from the reading set so the two
 * stay consistent. Buckets by the user's LOCAL calendar day — a 7:30am
 * Sydney reading belongs to that Sydney day, not the UTC one.
 */
export function aggregateTrend(readings: BpReadingRow[]): BpTrendRow[] {
  const byDay = new Map<string, BpReadingRow[]>();
  for (const r of readings) {
    const day = localDay(r.effective_time);
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
