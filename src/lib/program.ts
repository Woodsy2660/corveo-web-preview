/**
 * Program helpers. The chapter content itself lives in
 * src/copy/program-placeholder.ts and is replaced verbatim by Corveo's
 * signed-off curriculum; these are the lookups and the mapping onto
 * `v_program_progress.completed_steps`.
 */

import {
  PROGRAM_PLACEHOLDER_WEEKS,
  type ProgramChapter,
} from "@/copy/program-placeholder";
import type { ProgramProgressRow } from "@/lib/api/types";

export const PROGRAM_CHAPTERS = PROGRAM_PLACEHOLDER_WEEKS;
export const PROGRAM_WEEK_COUNT = PROGRAM_PLACEHOLDER_WEEKS.length;

/** Key used in `completed_steps` (docs/02 §4.3). One entry per chapter. */
export function stepKey(week: number): string {
  return `week-${week}`;
}

export function findChapter(week: number): ProgramChapter | undefined {
  return PROGRAM_CHAPTERS.find((c) => c.week === week);
}

export function isRead(progress: ProgramProgressRow | undefined, week: number): boolean {
  return progress?.completed_steps?.[stepKey(week)] === true;
}

/**
 * A chapter is available once the program reaches its week. Content is
 * released on the six-week cadence, never in response to readings.
 */
export function isAvailable(progress: ProgramProgressRow | undefined, week: number): boolean {
  return week <= (progress?.current_week ?? 1);
}

export function readCount(progress: ProgramProgressRow | undefined): number {
  return PROGRAM_CHAPTERS.filter((c) => isRead(progress, c.week)).length;
}
