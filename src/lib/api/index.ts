/**
 * API factory. Screens import the api instance and React Query hooks from
 * here only — never a concrete implementation. BEN: the Supabase-backed
 * implementation of CorveoApi replaces createMockApi() here at integration.
 */

import type { CorveoApi } from "./types";
import { createMockApi } from "./mock";

let instance: CorveoApi | null = null;

export function getApi(): CorveoApi {
  if (!instance) {
    instance = createMockApi();
  }
  return instance;
}

export * from "./types";
export { BOUNDS, BP_PANEL_CODE, validateManualEntry, isValidManualEntry } from "./bounds";
export type { ManualEntryDraft, ManualEntryErrors } from "./bounds";
