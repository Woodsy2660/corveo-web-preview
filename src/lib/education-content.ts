/**
 * Education content from the Lovable-Andrew handoff.
 *
 * Six-week chapters: `02_CONTENT_ALL_SIX_WEEKS.json`.
 * Pulse bodies: `pulse-articles.json` (CORV-EDU-002 v0.4, clinically accepted
 * 24 Sep 2026). Render body text byte-identical — do not rewrite it.
 * In Focus bodies are not supplied: show emptyReaderMessage, never invent text.
 *
 * `publishable` stays false. CON-04 remains closed.
 */

import raw from "@/copy/02_CONTENT_ALL_SIX_WEEKS.json";
import pulseRaw from "@/copy/pulse-articles.json";

export type EducationBlock =
  | { type: "paragraph"; text: string }
  | { type: "list"; items: readonly string[] };

export interface EducationCrossLink {
  title: string;
  collection: "pulse" | "in-focus" | string;
  prototypeTargetKey: string;
}

export interface PulseReference {
  id: string;
  citation: string;
  verificationStatus: string;
}

export interface EditorialEntry {
  slug: string;
  prototypeKey: string;
  collection: "pulse" | "in-focus";
  title: string;
  excerpt: string;
  standfirst: string | null;
  body: readonly string[] | null;
  keyTakeaway: string | null;
  sharedFooter: string | null;
  bylineStatus: string | null;
  emptyReaderMessage: string;
  reviewStatus: string;
  byline: string | null;
  readMinutes: number;
  displayReadingTime: boolean;
  setupAccess: boolean;
  publishable: boolean;
  doNotGenerateBody: boolean;
  bodySHA256: string | null;
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

interface PulseArticleJson {
  prototypeKey: string;
  title: string;
  linkedFromWeeks: number[];
  setupAccess: boolean;
  cardSummary: string;
  standfirst: string;
  body: string[];
  keyTakeaway: string;
  sharedFooter: string;
  byline: string;
  bylineStatus: string;
  clinicalReviewStatus: string;
  displayReadingTime: boolean;
  doNotGenerateBody: boolean;
  publishable: boolean;
  bodySHA256: string;
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
const pulsePkg = pulseRaw as {
  articles: PulseArticleJson[];
  references: PulseReference[];
};

const pulseByKey = new Map(pulsePkg.articles.map((a) => [a.prototypeKey, a]));

export const EDUCATION_PROGRAM = pkg.program;

function editorial(entry: RawEditorial): EditorialEntry {
  const pulse = pulseByKey.get(entry.prototypeKey);
  return {
    slug: entry.prototypeKey,
    prototypeKey: entry.prototypeKey,
    collection: entry.collection === "in-focus" ? "in-focus" : "pulse",
    title: pulse?.title ?? entry.title,
    excerpt: pulse?.cardSummary ?? entry.cardSummary ?? "",
    standfirst: pulse?.standfirst ?? null,
    body: pulse?.body ?? null,
    keyTakeaway: pulse?.keyTakeaway ?? null,
    sharedFooter: pulse?.sharedFooter ?? null,
    bylineStatus: pulse?.bylineStatus ?? null,
    emptyReaderMessage: entry.emptyReaderMessage,
    reviewStatus: pulse?.clinicalReviewStatus ?? entry.clinicalReviewStatus,
    byline: pulse?.byline ?? entry.byline,
    readMinutes: entry.referenceScreenReadingTimeMinutes ?? 0,
    displayReadingTime: pulse?.displayReadingTime ?? entry.displayReadingTime,
    setupAccess: pulse?.setupAccess ?? false,
    publishable: pulse?.publishable ?? false,
    doNotGenerateBody: pulse?.doNotGenerateBody ?? entry.collection === "in-focus",
    bodySHA256: pulse?.bodySHA256 ?? null,
  };
}

const baseChapters = pkg.chapters.map((ch) => ({
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

export const EDUCATION_CHAPTERS = baseChapters.map((ch) => {
  const extras: EducationCrossLink[] = pulsePkg.articles
    .filter((a) => a.linkedFromWeeks.includes(ch.week))
    .map((a) => ({
      title: a.title,
      collection: "pulse" as const,
      prototypeTargetKey: a.prototypeKey,
    }));
  const crossLinks = [...ch.crossLinks];
  for (const link of extras) {
    if (!crossLinks.some((x) => x.prototypeTargetKey === link.prototypeTargetKey)) {
      crossLinks.push(link);
    }
  }
  return { ...ch, crossLinks };
});

export const PULSE_CATALOGUE: readonly EditorialEntry[] = pkg.editorialCatalogue
  .filter((e) => e.collection === "pulse")
  .map(editorial);

export const IN_FOCUS_CATALOGUE: readonly EditorialEntry[] = pkg.editorialCatalogue
  .filter((e) => e.collection === "in-focus")
  .map(editorial);

export const SETUP_PULSE_ARTICLES: readonly EditorialEntry[] = PULSE_CATALOGUE.filter(
  (e) => e.setupAccess,
);

/** Loaded for a future references screen. Not wired into navigation (citation treatment is blocked). */
export const PULSE_REFERENCES: readonly PulseReference[] = pulsePkg.references;

export function findEditorial(slug: string | undefined): EditorialEntry | undefined {
  if (!slug) return undefined;
  return [...PULSE_CATALOGUE, ...IN_FOCUS_CATALOGUE].find((e) => e.slug === slug);
}

export const HAS_DRAFT_CONTENT =
  pkg.chapters.some((ch) => !ch.publishable) ||
  PULSE_CATALOGUE.some((e) => !e.publishable) ||
  IN_FOCUS_CATALOGUE.some((e) => !e.publishable);

/** CON-04: a release must not ship while any education content is unpublishable. */
export const CON04_RELEASE_BLOCKED = HAS_DRAFT_CONTENT;
