import { useState } from "react";
import { Field } from "@/components/ui/Field";
import { Button } from "@/components/ui/Button";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { VALIDATION_PLEASE_CHECK, VALIDATION_SYSTOLIC_GREATER } from "@/copy/validation";
import { BP_PANEL_CODE, BOUNDS, validateManualEntry } from "@/lib/api";
import { useIngestObservations } from "@/lib/api/hooks";
import { localTzInfo, nowLocalInputValue } from "@/lib/format";
import type { IngestResponse } from "@/lib/api/types";

/** The reading as submitted, for screens that show it back immediately. */
export interface SubmittedReading {
  systolic: number;
  diastolic: number;
  effective_time: string;
  source_type: "manual";
}

/**
 * Manual BP entry (Deliverable 4). Bounds are data quality only — the form
 * catches typos and says nothing about what a plausible value means. Writes
 * through the same ingest path as the plugin, with context tags carried in
 * the observation's `context` jsonb.
 */
export function ManualEntryForm({
  ctaLabel,
  onSaved,
}: {
  ctaLabel: string;
  onSaved: (result: IngestResponse, submitted: SubmittedReading) => void;
}) {
  const ingest = useIngestObservations();
  const [systolic, setSystolic] = useState("");
  const [diastolic, setDiastolic] = useState("");
  const [takenAt, setTakenAt] = useState(nowLocalInputValue());
  // No default: the arm is the patient's to state, not the form's to assume.
  // The record allows it to be absent (docs/02 §body_site, 0..1).
  const [arm, setArm] = useState<"left" | "right" | null>(null);
  const [showErrors, setShowErrors] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const errors = validateManualEntry({ systolic, diastolic });
  const c = JOURNEY.firstCapture;

  const fieldError = (key: "systolic" | "diastolic"): string | undefined => {
    if (!showErrors) return undefined;
    if (errors[key]) return VALIDATION_PLEASE_CHECK;
    if (key === "diastolic" && errors.cross) return VALIDATION_SYSTOLIC_GREATER;
    return undefined;
  };

  const save = async () => {
    setShowErrors(true);
    setFormError(null);
    if (Object.keys(errors).length > 0) return;

    const taken = new Date(takenAt);
    const { tz, offsetMinutes } = localTzInfo(taken);
    const uuid = crypto.randomUUID();

    let result: IngestResponse;
    try {
      result = await ingest.mutateAsync({
      source_type: "manual",
      observations: [
        {
          source_uuid: uuid,
          code: BP_PANEL_CODE,
          effective_time: taken.toISOString(),
          effective_tz: tz,
          effective_offset_minutes: offsetMinutes,
          source_system: "com.corveo.bpreset",
          source_name: null,
          source_device_model: null,
          source_user_entered: true,
          body_site_code: arm === "left" ? "368208006" : arm === "right" ? "368209003" : null,
          context: arm ? { arm } : {},
          components: [
            {
              source_uuid: crypto.randomUUID(),
              code: BOUNDS.systolic.code,
              value_quantity: Number(systolic),
              value_unit: BOUNDS.systolic.unit,
            },
            {
              source_uuid: crypto.randomUUID(),
              code: BOUNDS.diastolic.code,
              value_quantity: Number(diastolic),
              value_unit: BOUNDS.diastolic.unit,
            },
          ],
        },
      ],
      });
    } catch {
      setFormError(APP.manualEntry.saveFailed);
      return;
    }

    // A duplicate means the reading is already in the record — treat as
    // saved. Rejection with nothing inserted means the values didn't pass
    // server-side bounds: stay on the form with mechanical copy only.
    if (result.inserted === 0 && result.duplicates === 0) {
      setFormError(VALIDATION_PLEASE_CHECK);
      return;
    }

    onSaved(result, {
      systolic: Number(systolic),
      diastolic: Number(diastolic),
      effective_time: taken.toISOString(),
      source_type: "manual",
    });
  };

  return (
    <div className="flex flex-col gap-[var(--spacing-sm)]">
      <div className="grid grid-cols-2 gap-[var(--spacing-xs)]">
        <Field
          id="systolic"
          label={c.systolicLabel}
          type="number"
          inputMode="numeric"
          value={systolic}
          onChange={(e) => setSystolic(e.target.value)}
          error={fieldError("systolic")}
        />
        <Field
          id="diastolic"
          label={c.diastolicLabel}
          type="number"
          inputMode="numeric"
          value={diastolic}
          onChange={(e) => setDiastolic(e.target.value)}
          error={fieldError("diastolic")}
        />
      </div>

      <Field
        id="takenAt"
        label={c.timeLabel}
        type="datetime-local"
        value={takenAt}
        max={nowLocalInputValue()}
        onChange={(e) => setTakenAt(e.target.value)}
      />

      <div>
        <span className="block pb-[var(--spacing-3xs)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
          {c.armLabel}
        </span>
        <div className="flex gap-[var(--spacing-2xs)]" role="radiogroup" aria-label={c.armLabel}>
          {(["left", "right"] as const).map((side) => (
            <button
              key={side}
              role="radio"
              aria-checked={arm === side}
              onClick={() => setArm(side)}
              className={`flex-1 rounded-round border py-[var(--spacing-2xs)] ${
                arm === side ? "border-heading bg-action text-action-ink" : "border-hairline bg-card"
              }`}
              style={{ fontSize: "var(--text-body-sm)" }}
            >
              {side === "left" ? c.armLeft : c.armRight}
            </button>
          ))}
        </div>
      </div>

      {formError ? (
        <p role="alert" className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
          {formError}
        </p>
      ) : null}

      <Button disabled={ingest.isPending} onClick={save}>
        {ingest.isPending ? APP.common.busy : ctaLabel}
      </Button>
    </div>
  );
}
