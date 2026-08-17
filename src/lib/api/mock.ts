/**
 * Mock implementation of the CorveoApi contract.
 *
 * DEV ONLY. Backs every screen until Ben's Supabase views and RPC are live;
 * removed entirely at integration. Holds synthetic data only — never real
 * patient data (SOW A.12.3) — persisted to localStorage so demo state
 * survives reloads. "Reset demo data" in Settings clears it.
 */

import type {
  BpReadingRow,
  ConsentEventInput,
  ConsentStatusRow,
  CorveoApi,
  ExportResult,
  IngestPayload,
  IngestRejection,
  IngestResponse,
  ProgramProgressRow,
} from "./types";
import { BOUNDS, BP_PANEL_CODE } from "./bounds";
import { aggregateTrend, buildSeedReadings } from "@/lib/mock/fixtures";

const STORE_KEY = "corveo.mock.v1";
const LATENCY_MS = 180;

interface MockStore {
  readings: BpReadingRow[];
  consent: ConsentStatusRow;
  progress: ProgramProgressRow;
  seenSourceUuids: string[];
  programStartedAt: string | null;
}

function freshStore(): MockStore {
  return {
    readings: buildSeedReadings(),
    consent: { has_active_consent: false, version: null, last_event_at: null },
    // Synthetic mid-program state so both the open and locked chapter states
    // are visible in the preview. The real cadence is server-side (Ben).
    progress: { current_week: 3, completed_steps: { "week-1": true } },
    seenSourceUuids: [],
    programStartedAt: null,
  };
}

function load(): MockStore {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (raw) return JSON.parse(raw) as MockStore;
  } catch {
    /* corrupted store falls through to fresh */
  }
  return freshStore();
}

function save(store: MockStore): void {
  localStorage.setItem(STORE_KEY, JSON.stringify(store));
}

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

export function resetMockStore(): void {
  localStorage.removeItem(STORE_KEY);
}

export function createMockApi(): CorveoApi {
  let store = load();

  const commit = () => save(store);

  return {
    async listReadings(opts) {
      await delay(LATENCY_MS);
      const limit = opts?.limit ?? 50;
      let rows = [...store.readings].sort((a, b) =>
        b.effective_time.localeCompare(a.effective_time),
      );
      if (opts?.before) {
        rows = rows.filter((r) => r.effective_time < opts.before!);
      }
      return rows.slice(0, limit);
    },

    async getTrend(opts) {
      await delay(LATENCY_MS);
      let rows = aggregateTrend(store.readings);
      if (opts?.sinceDay) rows = rows.filter((r) => r.day >= opts.sinceDay!);
      return rows;
    },

    async getConsentStatus() {
      await delay(LATENCY_MS);
      return store.consent;
    },

    async recordConsentEvent(input: ConsentEventInput) {
      await delay(LATENCY_MS);
      store.consent = {
        has_active_consent: input.action === "granted",
        version: input.version,
        last_event_at: new Date().toISOString(),
      };
      commit();
      return store.consent;
    },

    async ingestObservations(payload: IngestPayload): Promise<IngestResponse> {
      await delay(LATENCY_MS);
      let inserted = 0;
      let duplicates = 0;
      const rejected: IngestRejection[] = [];

      for (const obs of payload.observations) {
        if (store.seenSourceUuids.includes(obs.source_uuid)) {
          duplicates++;
          continue;
        }
        if (obs.code !== BP_PANEL_CODE) {
          rejected.push({
            source_uuid: obs.source_uuid,
            reason: "UNKNOWN_CODE",
            detail: obs.code,
          });
          continue;
        }
        const sys = obs.components.find((c) => c.code === BOUNDS.systolic.code);
        const dia = obs.components.find((c) => c.code === BOUNDS.diastolic.code);
        if (!sys || !dia) {
          rejected.push({
            source_uuid: obs.source_uuid,
            reason: "MISSING_COMPONENT",
            detail: !sys ? BOUNDS.systolic.code : BOUNDS.diastolic.code,
          });
          continue;
        }
        const outOfBounds =
          sys.value_quantity < BOUNDS.systolic.min ||
          sys.value_quantity > BOUNDS.systolic.max ||
          dia.value_quantity < BOUNDS.diastolic.min ||
          dia.value_quantity > BOUNDS.diastolic.max;
        if (outOfBounds) {
          rejected.push({
            source_uuid: obs.source_uuid,
            reason: "VALUE_OUT_OF_BOUNDS",
            detail: `${sys.value_quantity}/${dia.value_quantity}`,
          });
          continue;
        }
        if (sys.value_quantity <= dia.value_quantity) {
          rejected.push({
            source_uuid: obs.source_uuid,
            reason: "SYSTOLIC_NOT_GREATER",
            detail: `${sys.value_quantity}/${dia.value_quantity}`,
          });
          continue;
        }

        store.readings.push({
          id: obs.source_uuid,
          effective_time: obs.effective_time,
          effective_tz: obs.effective_tz,
          systolic: sys.value_quantity,
          diastolic: dia.value_quantity,
          source_type: payload.source_type,
          source_name: obs.source_name,
          body_site_display:
            obs.body_site_code === "368209003"
              ? "Right arm"
              : obs.body_site_code === "368208006"
                ? "Left arm"
                : null,
        });
        store.seenSourceUuids.push(obs.source_uuid);
        inserted++;
      }

      commit();
      return { inserted, duplicates, soft_deleted: 0, rejected };
    },

    async getProgramProgress() {
      await delay(LATENCY_MS);
      return store.progress;
    },

    async updateProgramProgress(patch) {
      await delay(LATENCY_MS);
      store.progress = {
        current_week: patch.current_week ?? store.progress.current_week,
        completed_steps: {
          ...store.progress.completed_steps,
          ...(patch.completed_steps ?? {}),
        },
      };
      if (!store.programStartedAt) store.programStartedAt = new Date().toISOString();
      commit();
      return store.progress;
    },

    async exportPatientData(): Promise<ExportResult> {
      await delay(LATENCY_MS * 2);
      const header = "effective_time,effective_tz,systolic,diastolic,source_type,source_name";
      const lines = store.readings.map(
        (r) =>
          `${r.effective_time},${r.effective_tz},${r.systolic},${r.diastolic},${r.source_type},${r.source_name ?? ""}`,
      );
      return {
        fhir_bundle: {
          resourceType: "Bundle",
          type: "collection",
          note: "MOCK export — real FHIR R4 Bundle is produced server-side (docs/02 §4.4)",
          total: store.readings.length,
        },
        csv: [header, ...lines].join("\n"),
      };
    },

    async requestAccountDeletion() {
      await delay(LATENCY_MS * 2);
      // Real behaviour is deletion-with-logging against the retention floor
      // (SOW A.12.6), executed server-side. The mock just clears local state.
      store = freshStore();
      commit();
      return { acknowledged: true };
    },
  };
}
