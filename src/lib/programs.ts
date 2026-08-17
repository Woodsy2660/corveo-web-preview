/**
 * Program catalogue and follow state.
 *
 * CONTRACT GAP — read before wiring Supabase. `v_program_progress` is
 * `{ current_week, completed_steps }`: one program, no identifier. Following
 * several programs, or tracking progress per program, needs a spec change in
 * docs/02 Part 4 (Ben's lane), and shipping the wider library at all is a
 * Change Request against Deliverable 7.
 *
 * Until then:
 *  - which programs you follow lives in localStorage, not the API;
 *  - `completed_steps` keys are namespaced `"<slug>:<n>"` so progress already
 *    written survives the migration mechanically;
 *  - `current_week` continues to gate the core program only. Library
 *    programs are not week-gated, because one integer cannot gate five
 *    programs independently.
 */

import {
  CORE_PROGRAM_SLUG,
  PROGRAMS,
  type ProgramSummary,
} from "@/copy/programs-placeholder";
import type { ProgramChapter } from "@/copy/program-placeholder";
import type { ProgramProgressRow } from "@/lib/api/types";

export { PROGRAMS, CORE_PROGRAM_SLUG };
export type { ProgramSummary };

const FOLLOW_KEY = "corveo.programs.v1";

interface FollowState {
  following: string[];
  active: string;
}

const DEFAULT_FOLLOW: FollowState = {
  following: [CORE_PROGRAM_SLUG],
  active: CORE_PROGRAM_SLUG,
};

export function loadFollowState(): FollowState {
  try {
    const raw = localStorage.getItem(FOLLOW_KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<FollowState>;
      const following = (parsed.following ?? []).filter((s) => findProgram(s));
      const active =
        parsed.active && following.includes(parsed.active)
          ? parsed.active
          : (following[0] ?? "");
      return { following, active };
    }
  } catch {
    /* corrupted state falls through to the default */
  }
  return DEFAULT_FOLLOW;
}

export function saveFollowState(state: FollowState): void {
  localStorage.setItem(FOLLOW_KEY, JSON.stringify(state));
}

export function findProgram(slug: string | undefined): ProgramSummary | undefined {
  return PROGRAMS.find((p) => p.slug === slug);
}

export function coreProgram(): ProgramSummary {
  // The catalogue always contains the core program; the non-null assertion
  // documents that rather than threading an impossible undefined everywhere.
  return findProgram(CORE_PROGRAM_SLUG)!;
}

export function findChapter(
  slug: string | undefined,
  n: number,
): ProgramChapter | undefined {
  return findProgram(slug)?.chapters.find((c) => c.week === n);
}

/** Key used in `completed_steps`. Namespaced so several programs can coexist. */
export function stepKey(slug: string, n: number): string {
  return `${slug}:${n}`;
}

export function isRead(
  progress: ProgramProgressRow | undefined,
  slug: string,
  n: number,
): boolean {
  const steps = progress?.completed_steps;
  if (!steps) return false;
  // Legacy un-namespaced keys from before the catalogue existed.
  return steps[stepKey(slug, n)] === true || (slug === CORE_PROGRAM_SLUG && steps[`week-${n}`] === true);
}

/**
 * The core program releases a chapter a week; library programs open in full.
 * A single `current_week` cannot gate five programs independently — see the
 * contract gap above.
 */
export function isAvailable(
  progress: ProgramProgressRow | undefined,
  program: ProgramSummary,
  n: number,
): boolean {
  if (!program.core) return true;
  return n <= (progress?.current_week ?? 1);
}

export function readCount(
  progress: ProgramProgressRow | undefined,
  program: ProgramSummary,
): number {
  return program.chapters.filter((c) => isRead(progress, program.slug, c.week)).length;
}
