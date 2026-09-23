/**
 * Education content from the Lovable-Andrew handoff
 * (`02_CONTENT_ALL_SIX_WEEKS.json`).
 *
 * The copy is the client's. Render it; do not rewrite it. Pulse and In Focus
 * bodies are not supplied — show emptyReaderMessage, never invent text.
 */

import raw from "@/copy/02_CONTENT_ALL_SIX_WEEKS.json";

export type EducationBlock =
  | { type: "paragraph"; text: string }
  | { type: "list"; items: readonly string[] };

export interface EducationCrossLink {
  title: string;
  collection: "pulse" | "in-focus" | string;
  prototypeTargetKey: string;
}

export interface EditorialEntry {
  slug: string;
  prototypeKey: string;
  collection: "pulse" | "in-focus";
  title: string;
  excerpt: string;
  emptyReaderMessage: string;
  reviewStatus: string;
  byline: string | null;
  readMinutes: number;
  displayReadingTime: boolean;
}

interface RawChapter {
  week: number;
  title: string;
  cardSummary: string;
  standfirst: string;
  readingTimeMinutes: number;
  byline: string;
  clinicalReviewStatus: string;
  sections: { heading: string; blocks: EducationBlock[] }[];
  keyTakeaway: string;
  nextWeekTitle: string | null;
  reviewHolds: string[];
  publishable: boolean;
  crossLinks: EducationCrossLink[];
}

interface RawEditorial {
  prototypeKey: string;
  collection: string;
  title: string;
  cardSummary: string | null;
  emptyReaderMessage: string;
  clinicalReviewStatus: string;
  byline: string | null;
  referenceScreenReadingTimeMinutes: number | null;
  displayReadingTime: boolean;
}

interface RawPackage {
  program: {
    title: string;
    description: string;
    previewBanner: string;
    week4Notice: string;
    byline: string;
    clinicalReviewStatus: string;
  };
  chapters: RawChapter[];
  editorialCatalogue: RawEditorial[];
}

const pkg = raw as RawPackage;

export const EDUCATION_PROGRAM = pkg.program;

export const EDUCATION_CHAPTERS = pkg.chapters.map((ch) => ({
  week: ch.week,
  title: ch.title,
  excerpt: ch.cardSummary,
  deck: ch.standfirst,
  readMinutes: ch.readingTimeMinutes,
  reviewStatus: ch.clinicalReviewStatus,
  byline: ch.byline,
  keyTakeaway: ch.keyTakeaway,
  nextWeekTitle: ch.nextWeekTitle ?? undefined,
  reviewHolds: ch.reviewHolds,
  publishable: ch.publishable,
  crossLinks: ch.crossLinks,
  sections: ch.sections.map((s) => ({
    heading: s.heading,
    blocks: s.blocks,
  })),
}));

function editorial(entry: RawEditorial): EditorialEntry {
  return {
    slug: entry.prototypeKey,
    prototypeKey: entry.prototypeKey,
    collection: entry.collection === "in-focus" ? "in-focus" : "pulse",
    title: entry.title,
    excerpt: entry.cardSummary ?? "",
    emptyReaderMessage: entry.emptyReaderMessage,
    reviewStatus: entry.clinicalReviewStatus,
    byline: entry.byline,
    readMinutes: entry.referenceScreenReadingTimeMinutes ?? 0,
    displayReadingTime: entry.displayReadingTime,
  };
}

export const PULSE_CATALOGUE: readonly EditorialEntry[] = pkg.editorialCatalogue
  .filter((e) => e.collection === "pulse")
  .map(editorial);

export const IN_FOCUS_CATALOGUE: readonly EditorialEntry[] = pkg.editorialCatalogue
  .filter((e) => e.collection === "in-focus")
  .map(editorial);

export function findEditorial(slug: string | undefined): EditorialEntry | undefined {
  if (!slug) return undefined;
  return [...PULSE_CATALOGUE, ...IN_FOCUS_CATALOGUE].find((e) => e.slug === slug);
}

export const HAS_DRAFT_CONTENT = pkg.chapters.some((ch) => !ch.publishable);
