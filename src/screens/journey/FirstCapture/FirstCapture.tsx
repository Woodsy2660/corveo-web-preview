import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { StepDots } from "@/components/ui/StepDots";
import { ManualEntryForm } from "@/components/ManualEntryForm";
import { JOURNEY } from "@/copy/journey";
import { useJourney } from "@/lib/journey/state";

/** Journey step 4 — first capture. */
export function FirstCapture() {
  const navigate = useNavigate();
  const { connectChoice } = useJourney();
  const c = JOURNEY.firstCapture;

  return (
    <Screen eyebrow={c.eyebrow} title={c.title}>
      <StepDots total={5} current={4} />
      <p className="pb-[var(--spacing-md)] text-ink-secondary">{c.intro}</p>

      {connectChoice === "healthkit" ? (
        <Card className="mb-[var(--spacing-sm)]">
          <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {c.healthkitWaiting}
          </p>
        </Card>
      ) : null}

      <ManualEntryForm
        ctaLabel={c.cta}
        onSaved={(_result, submitted) =>
          navigate("/journey/result", { state: { reading: submitted } })
        }
      />
    </Screen>
  );
}
