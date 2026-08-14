/**
 * Web/dev mock of CorveoHealthPlugin.
 *
 * Implements the frozen bridge interface (docs/03 §3) so the front end can
 * be built and demonstrated before Luca's native plugin lands. On device,
 * the factory in index.ts swaps this for the registered Capacitor plugin.
 *
 * Honours the permission-state rule: never reports `denied` — three states
 * only (docs/03 §4).
 */

import type {
  AuthorizationResult,
  AuthorizationState,
  CorveoHealthPlugin,
  PermissionState,
  PluginListenerHandle,
  SyncError,
  SyncResult,
  SyncStatus,
} from "./types";

const STATE_KEY = "corveo.mock.health.v1";

interface MockHealthState {
  permission: PermissionState;
  observing: boolean;
  hasCredentials: boolean;
  lastSuccessfulSyncAt: string | null;
  samplesEverReceived: boolean;
}

function load(): MockHealthState {
  try {
    const raw = localStorage.getItem(STATE_KEY);
    if (raw) return JSON.parse(raw) as MockHealthState;
  } catch {
    /* fall through */
  }
  return {
    permission: "notDetermined",
    observing: false,
    hasCredentials: false,
    lastSuccessfulSyncAt: null,
    samplesEverReceived: true,
  };
}

export function resetMockHealth(): void {
  localStorage.removeItem(STATE_KEY);
}

type Listener = (data: SyncResult | SyncError) => void;

export function createMockHealthPlugin(): CorveoHealthPlugin {
  let state = load();
  const listeners = new Map<"syncCompleted" | "syncFailed", Set<Listener>>();

  const commit = () => localStorage.setItem(STATE_KEY, JSON.stringify(state));

  const emit = (event: "syncCompleted" | "syncFailed", data: SyncResult | SyncError) => {
    listeners.get(event)?.forEach((fn) => fn(data));
  };

  const syncResult = (inserted: number): SyncResult => ({
    inserted,
    duplicates: 0,
    softDeleted: 0,
    rejected: 0,
    anchorAdvanced: inserted > 0,
    completedAt: new Date().toISOString(),
  });

  return {
    async requestAuthorization(): Promise<AuthorizationResult> {
      // The mock simulates the sheet being shown; the outcome is unknowable
      // by design, so the state moves to `requested`, never a boolean.
      state.permission = "requested";
      commit();
      return {
        state: state.permission,
        requestedTypes: ["bloodPressureSystolic", "bloodPressureDiastolic", "heartRate"],
      };
    },

    async getAuthorizationState(): Promise<AuthorizationState> {
      return {
        state: state.permission,
        lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
        samplesEverReceived: state.samplesEverReceived,
      };
    },

    async startObserving() {
      state.observing = true;
      commit();
    },

    async stopObserving() {
      state.observing = false;
      commit();
    },

    async syncNow(): Promise<SyncResult> {
      const result = syncResult(0);
      state.lastSuccessfulSyncAt = result.completedAt;
      commit();
      emit("syncCompleted", result);
      return result;
    },

    async getSyncStatus(): Promise<SyncStatus> {
      return {
        observing: state.observing,
        hasAnchor: state.lastSuccessfulSyncAt !== null,
        hasCredentials: state.hasCredentials,
        lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
        lastAttemptAt: state.lastSuccessfulSyncAt,
        lastError: null,
        pendingRetry: false,
      };
    },

    async setCredentials() {
      state.hasCredentials = true;
      commit();
    },

    async clearCredentials() {
      state.hasCredentials = false;
      state.lastSuccessfulSyncAt = null;
      commit();
    },

    async addListener(event, fn): Promise<PluginListenerHandle> {
      const set = listeners.get(event) ?? new Set<Listener>();
      set.add(fn);
      listeners.set(event, set);
      return {
        remove: async () => {
          set.delete(fn);
        },
      };
    },
  };
}
