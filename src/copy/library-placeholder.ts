/**
 * PLACEHOLDER publication library — development only.
 *
 * Mirrors the two editorial collections on corveo.vercel.app so the app's
 * Learn tab has the same shape the site already publishes:
 *
 *  - The Pulse — "Short reads that answer your questions". One read fits one
 *    screen; the app presents them as a full-screen swipe-through deck.
 *  - In Focus — "Long reads that answer your questions". Article-length,
 *    presented on the same reading template as program chapters.
 *
 * SCOPE: neither collection is in the sixteen deliverables. Publishing the
 * site's editorial content in the app is a Change Request; this placeholder
 * exists so the IA can be built and reviewed. Real content is authored,
 * bylined and clinically reviewed by Corveo, and how it reaches the app
 * (CMS feed vs. bundled) is an open question for that Change Request.
 *
 * Same discipline as the program placeholders: bodies exist only for topics
 * that are purely descriptive — measurement mechanics, how records work.
 * Anything that would put words in Corveo's mouth (diet, caffeine, medication,
 * anything answer-shaped) stays card-metadata only and renders as pending.
 * Display, never interpret.
 */

import type { ProgramSection } from "./program-placeholder";

const PENDING = "Pending";

/** One short read. The whole body is meant to fit one phone screen. */
export interface PulseItem {
  slug: string;
  title: string;
  /** Absent means the read has not been supplied yet — renders as pending. */
  body?: readonly string[];
  /** Attribution slot — the site bylines these to a named cardiologist. */
  reviewStatus: string;
}

/** One long read, on the same reading template as a program chapter. */
export interface InFocusArticle {
  slug: string;
  title: string;
  /** One-line summary on the list card. */
  excerpt: string;
  /** Standfirst shown under the title in the reading view. */
  deck?: string;
  readMinutes: number;
  reviewStatus: string;
  /** Absent means the body content has not been supplied yet. */
  sections?: readonly ProgramSection[];
}

export const PULSE_ITEMS: readonly PulseItem[] = [
  {
    slug: "why-readings-vary",
    title: "Why readings vary through the day",
    reviewStatus: PENDING,
    body: [
      "Blood pressure is not a fixed property like height. It shifts with posture, activity, conversation, caffeine, sleep and the time since you last moved.",
      "That is why a record built over weeks says more than any single reading — and why your record keeps every reading exactly as your monitor reported it.",
    ],
  },
  {
    slug: "what-mmhg-measures",
    title: "What mmHg actually measures",
    reviewStatus: PENDING,
    body: [
      "Millimetres of mercury — mmHg — is a unit of pressure. Early monitors measured how far a column of mercury rose against a scale, and the unit outlived the mercury.",
      "A reading's two numbers use the same unit: pressure as the heart contracts, and pressure as it relaxes between beats.",
    ],
  },
  {
    slug: "the-white-coat-effect",
    title: "The white-coat effect",
    reviewStatus: PENDING,
    body: [
      "Readings taken in a clinic are often different from readings taken at home — the setting itself can change the measurement. Researchers call this the white-coat effect.",
      "It is one reason clinicians ask for home readings taken over time: a record built where you live shows a picture the clinic visit can't.",
    ],
  },
  {
    slug: "cuff-size-and-fit",
    title: "Cuff size and fit",
    reviewStatus: PENDING,
  },
  {
    slug: "morning-and-evening",
    title: "Morning and evening readings",
    reviewStatus: PENDING,
  },
  {
    slug: "home-records-in-clinic",
    title: "How clinicians use home records",
    reviewStatus: PENDING,
  },
] as const;

export const IN_FOCUS_ARTICLES: readonly InFocusArticle[] = [
  {
    slug: "the-home-record-explained",
    title: "The home record, explained",
    excerpt: "What a record built at home contains, and why it is kept exactly as measured.",
    deck: "A home blood pressure record is a simple thing: readings, kept in order, exactly as your monitor reported them. This article walks through what that record contains and how it is kept.",
    readMinutes: 6,
    reviewStatus: PENDING,
    sections: [
      {
        heading: "What a record contains",
        body: [
          "Each entry in your record is one measurement: two pressures in mmHg, taken at one moment, by your own validated monitor. The app adds the time and the source — Apple Health or manual entry — and nothing else.",
          "Readings are never adjusted, smoothed or scored. What your monitor reported is what your record keeps.",
        ],
      },
      {
        heading: "Why order and time matter",
        body: [
          "A record is more than a pile of numbers — the sequence carries information. When each reading was taken, and what the record looks like across weeks, is what your own clinician can read and discuss with you.",
        ],
      },
      {
        heading: "Whose record it is",
        body: [
          "Yours. The record can be exported as a file at any time, and deletion can be requested from Settings. Nothing is sent to a doctor or clinic by the app.",
        ],
      },
    ],
  },
  {
    slug: "how-a-monitor-works",
    title: "How a blood pressure monitor works",
    excerpt: "What happens between the cuff inflating and the numbers appearing.",
    readMinutes: 7,
    reviewStatus: PENDING,
  },
  {
    slug: "what-a-clinician-looks-at",
    title: "What a clinician looks at in a record",
    excerpt: "How home readings are read in clinic, and what makes a record useful.",
    readMinutes: 8,
    reviewStatus: PENDING,
  },
  {
    slug: "a-short-history-of-measurement",
    title: "A short history of measuring blood pressure",
    excerpt: "From a column of mercury to the cuff on your kitchen table.",
    readMinutes: 5,
    reviewStatus: PENDING,
  },
] as const;

export function findPulseItem(slug: string | undefined): PulseItem | undefined {
  return PULSE_ITEMS.find((p) => p.slug === slug);
}

export function findInFocusArticle(slug: string | undefined): InFocusArticle | undefined {
  return IN_FOCUS_ARTICLES.find((a) => a.slug === slug);
}
