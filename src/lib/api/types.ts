/**
 * API contract types.
 *
 * Shapes mirror docs/02-data-model-and-api.md Part 4 exactly. The front end
 * codes against views and the ingest RPC, never base tables. When the real
 * Supabase client lands (Ben's lane), these types are the compatibility
 * check between mock and production.
 */

/** Row shape of `v_bp_readings` (§4.3). */
export interface BpReadingRow {
  id: string;
  effective_time: string; // ISO 8601 UTC
  effective_tz: string; // IANA, e.g. "Australia/Sydney"
  systolic: number;
  diastolic: number;
  source_type: "healthkit" | "manual";
  source_name: string | null;
  body_site_display: string | null;
}

/** Row shape of `v_bp_trend` (§4.3) — daily aggregate, computed server-side. */
export interface BpTrendRow {
  day: string; // YYYY-MM-DD
  min_systolic: number;
  max_systolic: number;
  mean_systolic: number;
  min_diastolic: number;
  max_diastolic: number;
  mean_diastolic: number;
  reading_count: number;
}

/** Row shape of `v_consent_status` (§4.3). */
export interface ConsentStatusRow {
  has_active_consent: boolean;
  version: string | null;
  last_event_at: string | null;
}

/** Row shape of `v_program_progress` (§4.3). */
export interface ProgramProgressRow {
  current_week: number;
  completed_steps: Record<string, boolean>;
}

/** Observation component in the ingest payload (§4.2). */
export interface IngestComponent {
  source_uuid: string;
  code: string; // LOINC: "8480-6" systolic, "8462-4" diastolic
  value_quantity: number;
  value_unit: string; // "mm[Hg]"
}

/** One observation in the ingest payload (§4.2). */
export interface IngestObservation {
  source_uuid: string;
  code: string; // LOINC: "85354-9" BP panel
  effective_time: string;
  effective_tz: string;
  effective_offset_minutes: number;
  source_system: string;
  source_name: string | null;
  source_device_model: string | null;
  source_user_entered: boolean;
  body_site_code: string | null;
  context: Record<string, unknown>;
  components: IngestComponent[];
}

export interface IngestPayload {
  source_type: "healthkit" | "manual";
  observations: IngestObservation[];
  deleted_source_uuids?: string[];
}

/** Stable rejection reasons (§4.2). */
export type RejectionReason =
  | "VALUE_OUT_OF_BOUNDS"
  | "UNIT_MISMATCH"
  | "UNKNOWN_CODE"
  | "SYSTOLIC_NOT_GREATER"
  | "MALFORMED_TIMESTAMP"
  | "MISSING_COMPONENT";

export interface IngestRejection {
  source_uuid: string;
  reason: RejectionReason;
  detail: string;
}

export interface IngestResponse {
  inserted: number;
  duplicates: number;
  soft_deleted: number;
  rejected: IngestRejection[];
}

/** Consent event write (Deliverable 13 / §1 consent_event). */
export interface ConsentEventInput {
  action: "granted" | "withdrawn";
  version: string;
  document_hash: string; // SHA-256 of the exact consent text shown
  method: "in_app_explicit";
}

/** Export result (§4.4) — FHIR R4 Bundle plus CSV. */
export interface ExportResult {
  fhir_bundle: unknown;
  csv: string;
}

/**
 * The API surface the front end consumes. One mock implementation today
 * (src/lib/api/mock.ts); the Supabase-backed implementation replaces it at
 * integration without touching any screen.
 */
export interface CorveoApi {
  listReadings(opts?: { before?: string; limit?: number }): Promise<BpReadingRow[]>;
  getTrend(opts?: { sinceDay?: string }): Promise<BpTrendRow[]>;
  getConsentStatus(): Promise<ConsentStatusRow>;
  recordConsentEvent(input: ConsentEventInput): Promise<ConsentStatusRow>;
  ingestObservations(payload: IngestPayload): Promise<IngestResponse>;
  getProgramProgress(): Promise<ProgramProgressRow>;
  updateProgramProgress(patch: Partial<ProgramProgressRow>): Promise<ProgramProgressRow>;
  exportPatientData(): Promise<ExportResult>;
  /** Deletion-with-logging per SOW A.12.6 — never an unconditional hard delete. */
  requestAccountDeletion(): Promise<{ acknowledged: boolean }>;
}
