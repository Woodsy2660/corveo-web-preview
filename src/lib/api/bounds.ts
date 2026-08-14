/**
 * Data-quality bounds, mirrored from the observation_definition seed values
 * in docs/02-data-model-and-api.md §1.3.
 *
 * These are input validation, not clinical interpretation (SOW Deliverable 4).
 * They exist to catch typos. Nothing here, and nothing built on top of it,
 * may comment on whether a plausible value is high, low, or concerning.
 */

export const BOUNDS = {
  systolic: { code: "8480-6", min: 60, max: 260, unit: "mm[Hg]" },
  diastolic: { code: "8462-4", min: 30, max: 160, unit: "mm[Hg]" },
} as const;

export const BP_PANEL_CODE = "85354-9";

export type FieldError = "OUT_OF_BOUNDS" | "SYSTOLIC_NOT_GREATER" | "REQUIRED";

export interface ManualEntryDraft {
  systolic: string;
  diastolic: string;
}

export interface ManualEntryErrors {
  systolic?: FieldError;
  diastolic?: FieldError;
  cross?: FieldError;
}

/** Pure validation for the manual-entry form. Mechanical only. */
export function validateManualEntry(draft: ManualEntryDraft): ManualEntryErrors {
  const errors: ManualEntryErrors = {};
  const sys = Number(draft.systolic);
  const dia = Number(draft.diastolic);

  if (draft.systolic.trim() === "" || Number.isNaN(sys)) {
    errors.systolic = "REQUIRED";
  } else if (sys < BOUNDS.systolic.min || sys > BOUNDS.systolic.max) {
    errors.systolic = "OUT_OF_BOUNDS";
  }

  if (draft.diastolic.trim() === "" || Number.isNaN(dia)) {
    errors.diastolic = "REQUIRED";
  } else if (dia < BOUNDS.diastolic.min || dia > BOUNDS.diastolic.max) {
    errors.diastolic = "OUT_OF_BOUNDS";
  }

  if (!errors.systolic && !errors.diastolic && sys <= dia) {
    errors.cross = "SYSTOLIC_NOT_GREATER";
  }

  return errors;
}

export function isValidManualEntry(draft: ManualEntryDraft): boolean {
  return Object.keys(validateManualEntry(draft)).length === 0;
}
