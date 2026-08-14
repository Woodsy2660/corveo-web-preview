/**
 * CorveoHealthPlugin bridge interface.
 *
 * Copied VERBATIM from docs/03-plugin-bridge-spec.md §3 — the frozen
 * contract between Luca's native plugin and the front end. Do not edit
 * without agreement across both lanes (open item P-01).
 */

export interface PluginListenerHandle {
  remove(): Promise<void>;
}

export type HealthErrorCode =
  | "CONSENT_REQUIRED"
  | "AUTH_REFRESH_FAILED"
  | "ANCHOR_CORRUPT"
  | "AUTHORIZATION_NOT_REQUESTED"
  | "NO_CREDENTIALS"
  | "NETWORK_UNAVAILABLE"
  | "INGEST_REJECTED";

export interface CorveoHealthPlugin {
  requestAuthorization(): Promise<AuthorizationResult>;
  getAuthorizationState(): Promise<AuthorizationState>;
  startObserving(): Promise<void>;
  stopObserving(): Promise<void>;
  syncNow(options?: { since?: string }): Promise<SyncResult>;
  getSyncStatus(): Promise<SyncStatus>;
  setCredentials(opts: {
    accessToken: string;
    refreshToken: string;
    userId: string;
    projectUrl: string;
    anonKey: string;
  }): Promise<void>;
  clearCredentials(): Promise<void>;
  addListener(
    event: "syncCompleted" | "syncFailed",
    fn: (data: SyncResult | SyncError) => void,
  ): Promise<PluginListenerHandle>;
}

/**
 * Three states only — never `denied`. HealthKit deliberately does not
 * disclose read refusal, so the app treats "authorised but no data" and
 * "denied" identically, with neutral copy (docs/03 §4).
 */
export type PermissionState = "notDetermined" | "requested" | "unknown";

export interface AuthorizationResult {
  state: PermissionState;
  requestedTypes: string[];
}

export interface AuthorizationState {
  state: PermissionState;
  lastSuccessfulSyncAt: string | null;
  samplesEverReceived: boolean;
}

export interface SyncResult {
  inserted: number;
  duplicates: number;
  softDeleted: number;
  rejected: number;
  anchorAdvanced: boolean;
  completedAt: string;
}

export interface SyncStatus {
  observing: boolean;
  hasAnchor: boolean;
  hasCredentials: boolean;
  lastSuccessfulSyncAt: string | null;
  lastAttemptAt: string | null;
  lastError: HealthErrorCode | null;
  pendingRetry: boolean;
}

export interface SyncError {
  code: HealthErrorCode;
  retryable: boolean;
  occurredAt: string;
}
