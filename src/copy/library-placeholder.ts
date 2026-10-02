/**
 * Learn catalogue. Pulse bodies come from CORV-EDU-002 (clinically accepted,
 * not gate-passed). In Focus bodies are not supplied — do not invent them.
 */

import {
  IN_FOCUS_CATALOGUE,
  PULSE_CATALOGUE,
  findEditorial,
  type EditorialEntry,
} from "@/lib/education-content";

export type PulseItem = EditorialEntry;
export type InFocusArticle = EditorialEntry;

export const PULSE_ITEMS: readonly PulseItem[] = PULSE_CATALOGUE;
export const IN_FOCUS_ARTICLES: readonly InFocusArticle[] = IN_FOCUS_CATALOGUE;

export function findPulseItem(slug: string | undefined): PulseItem | undefined {
  const item = findEditorial(slug);
  return item?.collection === "pulse" ? item : undefined;
}

export function findInFocusArticle(slug: string | undefined): InFocusArticle | undefined {
  const item = findEditorial(slug);
  return item?.collection === "in-focus" ? item : undefined;
}
