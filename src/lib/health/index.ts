/**
 * Health plugin factory.
 *
 * The front end only ever imports from here. On the web (dev, Vercel
 * preview) this returns the mock. LUCA: when the native plugin lands,
 * replace the web branch with Capacitor's registerPlugin("CorveoHealth")
 * — the interface in ./types.ts is the frozen contract, so no screen
 * changes are needed. See docs/04-front-end.md §6.
 */

import type { CorveoHealthPlugin } from "./types";
import { createMockHealthPlugin, resetMockHealth } from "./mock";

let instance: CorveoHealthPlugin | null = null;

export function getHealthPlugin(): CorveoHealthPlugin {
  if (!instance) {
    instance = createMockHealthPlugin();
  }
  return instance;
}

/**
 * DEV ONLY — clears persisted mock plugin state AND drops the singleton so
 * the next getHealthPlugin() starts from notDetermined.
 */
export function resetHealthPlugin(): void {
  resetMockHealth();
  instance = null;
}

export * from "./types";
