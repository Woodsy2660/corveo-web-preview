/**
 * Six-week program content. Chapter bodies come from the Lovable-Andrew
 * handoff (`02_CONTENT_ALL_SIX_WEEKS.json`) via education-content.ts.
 * Render that copy as supplied; do not rewrite it.
 */

import { EDUCATION_CHAPTERS, EDUCATION_PROGRAM } from "@/lib/education-content";
import type { EducationBlock, EducationCrossLink } from "@/lib/education-content";

export type ChapterMedium = "read" | "watch" | "listen";

export const PROGRAM = {
  title: EDUCATION_PROGRAM.title,
  description: EDUCATION_PROGRAM.description,
} as const;

export interface ProgramSection {
  heading: string;
  /** Legacy paragraph list used by library programs without JSON bodies. */
  body?: readonly string[];
  /** Authoritative blocks from the education package. */
  blocks?: readonly EducationBlock[];
}

export interface ProgramChapter {
  week: number;
  title: string;
  excerpt: string;
  deck?: string;
  readMinutes: number;
  medium?: ChapterMedium;
  reviewStatus: string;
  byline?: string;
  keyTakeaway?: string;
  nextWeekTitle?: string;
  reviewHolds?: readonly string[];
  publishable?: boolean;
  crossLinks?: readonly EducationCrossLink[];
  sections?: readonly ProgramSection[];
}

export const PROGRAM_PLACEHOLDER_WEEKS: readonly ProgramChapter[] = EDUCATION_CHAPTERS;
