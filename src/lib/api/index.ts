/**
 * API factory. Screens import the api instance and React Query hooks from
 * here only — never a concrete implementation. BEN: the Supabase-backed
 * implementation of CorveoApi replaces createMockApi() here at integration.
 */

import type { CorveoApi } from "./types";
import { createMockApi, resetMockStore } from "./mock";

let instance: CorveoApi | null = null;

export function getApi(): CorveoApi {
  if (!instance) {
    instance = createMockApi();
  }
  return instance;
}

/**
 * DEV ONLY — clears the persisted mock store AND drops the singleton, so the
 * next getApi() reloads fresh state. Clearing storage alone is not enough:
 * the instance's closure holds the old store and would re-persist it.
 */
export function resetApi(): void {
  resetMockStore();
  instance = null;
}

export * from "./types";
export { BOUNDS, BP_PANEL_CODE, validateManualEntry, isValidManualEntry } from "./bounds";
export type { ManualEntryDraft, ManualEntryErrors } from "./bounds";
