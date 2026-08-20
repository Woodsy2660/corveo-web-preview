/**
 * The simulated Apple Health store, for the web demo only.
 *
 * DEV ONLY, and it never ships — on device this whole file is replaced by
 * the real HealthKit store. It exists so the preview can show the one thing
 * a web build otherwise cannot: a reading arriving from a cuff, through
 * Apple Health, into the record.
 *
 * It also reproduces the permission rule honestly. `readable` is set by what
 * the patient did in the iOS sheet, and it is consulted *here* — the plugin
 * mock, and therefore the app, never reads it. When access was refused the
 * store simply returns nothing, which is indistinguishable from having no
 * readings at all. That indistinguishability is the point.
 *
 * Synthetic data only (SOW A.12.3).
 */

import { mulberry32 } from "@/lib/mock/fixtures";
import type { IngestObservation } from "@/lib/api/types";
import { BOUNDS, BP_PANEL_CODE } from "@/lib/api/bounds";

const KEY = "corveo.demo.health.v1";
const TZ = "Australia/Sydney";
const SOURCE = {
  system: "com.omronhealthcare.OmronConnect",
  name: "OMRON connect",
  device: "HEM-7361T",
} as const;

interface Sample {
  uuid: string;
  systolic: number;
  diastolic: number;
  takenAt: string;
}

interface DemoStore {
  /** Whether the simulated Health store will hand anything over. */
  readable: boolean;
  /** Samples written by a cuff and not yet read by the plugin. */
  unread: Sample[];
  /** Seed advanced per sample so a demo run is repeatable. */
  cursor: number;
}

function fresh(): DemoStore {
  return { readable: false, unread: [], cursor: 0 };
}

function load(): DemoStore {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) return { ...fresh(), ...(JSON.parse(raw) as DemoStore) };
  } catch {
    /* fall through */
  }
  return fresh();
}

let store = load();
const listeners = new Set<() => void>();

function commit() {
  localStorage.setItem(KEY, JSON.stringify(store));
  listeners.forEach((fn) => fn());
}

export function subscribeDemoHealth(fn: () => void): () => void {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function resetDemoHealth(): void {
  localStorage.removeItem(KEY);
  store = fresh();
  listeners.forEach((fn) => fn());
}

/** Set from the iOS sheet's toggles. Never read by the app. */
export function setStoreReadable(readable: boolean): void {
  store.readable = readable;
  commit();
}

export function unreadCount(): number {
  return store.unread.length;
}

function uuid(rand: () => number): string {
  const hex = "0123456789abcdef";
  let s = "";
  for (let i = 0; i < 32; i++) s += hex[Math.floor(rand() * 16)];
  return `${s.slice(0, 8)}-${s.slice(8, 12)}-4${s.slice(13, 16)}-8${s.slice(17, 20)}-${s.slice(20, 32)}`;
}

/**
 * A reading is taken on the cuff and lands in Apple Health. This happens
 * whether or not Corveo has permission — the cuff's own app writes it.
 *
 * Values are synthetic, drawn around the same baseline as the seeded
 * fixtures so the demo record stays coherent. No trend is built into them:
 * a demo dataset that drifts downward would imply an outcome the program
 * does not claim.
 */
export function takeCuffReading(): void {
  const rand = mulberry32(1337 + store.cursor * 7919);
  store.cursor += 1;
  store.unread.push({
    uuid: uuid(rand),
    systolic: 132 + Math.floor(rand() * 13),
    diastolic: 82 + Math.floor(rand() * 10),
    takenAt: new Date().toISOString(),
  });
  commit();
}

/**
 * What an anchored read returns. Refused access yields an empty array — the
 * same array an empty store yields.
 */
export function readUnread(): IngestObservation[] {
  if (!store.readable) return [];
  return store.unread.map((s) => ({
    source_uuid: s.uuid,
    code: BP_PANEL_CODE,
    effective_time: s.takenAt,
    effective_tz: TZ,
    effective_offset_minutes: 600,
    source_system: SOURCE.system,
    source_name: SOURCE.name,
    source_device_model: SOURCE.device,
    source_user_entered: false,
    body_site_code: null,
    context: {},
    components: [
      {
        source_uuid: `${s.uuid}-s`,
        code: BOUNDS.systolic.code,
        value_quantity: s.systolic,
        value_unit: BOUNDS.systolic.unit,
      },
      {
        source_uuid: `${s.uuid}-d`,
        code: BOUNDS.diastolic.code,
        value_quantity: s.diastolic,
        value_unit: BOUNDS.diastolic.unit,
      },
    ],
  }));
}

/**
 * Advance the cursor past samples that have been confirmed written. Only
 * called after the upload succeeds — anything unconfirmed stays unread and
 * is offered again next time.
 */
export function markRead(uuids: string[]): void {
  store.unread = store.unread.filter((s) => !uuids.includes(s.uuid));
  commit();
}
