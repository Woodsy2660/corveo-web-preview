import { useLocation, useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { Chip } from "@/components/ui/Chip";
import { StepDots } from "@/components/ui/StepDots";
import { JOURNEY } from "@/copy/journey";
import { APP } from "@/copy/app";
import { useReadings } from "@/lib/api/hooks";
import { fmtDateTime } from "@/lib/format";
import type { SubmittedReading } from "@/components/ManualEntryForm";

/**
 * Journey step 4b — result-as-context. Shows the just-saved reading in the
 * context of the program: exactly as recorded, no evaluation of any kind.
 * The just-saved reading arrives via navigation state — the latest-by-time
 * record is only a fallback, since a backdated first capture is not the
 * newest reading in the record.
 */
export function Result() {
  const navigate = useNavigate();
  const location = useLocation();
  const submitted = (location.state as { reading?: SubmittedReading } | null)?.reading;
  const { data: readings } = useReadings(1);
  const latest = submitted ?? readings?.[0];
  const c = JOURNEY.result;

  return (
    <Screen
      eyebrow={c.eyebrow}
      title={c.title}
      footer={<Button onClick={() => navigate("/journey/cadence")}>{c.cta}</Button>}
    >
      <StepDots total={5} current={4} />

      {latest ? (
        <div className="rounded-lg bg-card p-[var(--spacing-md)] text-center">
          <div className="font-display text-heading" style={{ fontSize: "56px", lineHeight: 1.1 }}>
            {latest.systolic}
            <span className="text-ink-tertiary"> / </span>
            {latest.diastolic}
          </div>
          <div className="eyebrow pt-[var(--spacing-2xs)]">{APP.common.unitMmHg}</div>
          <div className="flex justify-center gap-[var(--spacing-2xs)] pt-[var(--spacing-sm)]">
            <Chip>
              {latest.source_type === "healthkit" ? APP.readings.sourceHealth : APP.readings.sourceManual}
            </Chip>
            <Chip>{fmtDateTime(latest.effective_time)}</Chip>
          </div>
        </div>
      ) : null}

      <p className="pt-[var(--spacing-md)] text-ink-secondary">{c.body}</p>
    </Screen>
  );
}
