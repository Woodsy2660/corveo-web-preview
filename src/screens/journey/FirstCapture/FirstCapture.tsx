import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { ManualEntryForm } from "@/components/ManualEntryForm";
import { JOURNEY } from "@/copy/journey";
import { useJourney } from "@/lib/journey/state";

/**
 * Journey step 4 — first capture. A Health user may skip the form: the app
 * cannot know whether permission was granted (docs/03 §4), so the choice is
 * theirs, and it lands on the rhythm step rather than the result, which
 * would have nothing to show until the first sync runs.
 */
export function FirstCapture() {
  const navigate = useNavigate();
  const { connectChoice } = useJourney();
  const c = JOURNEY.firstCapture;

  return (
    <Screen overline={c.eyebrow} title={c.title} className="step-enter">
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

      {connectChoice === "healthkit" ? (
        <Button
          variant="ghost"
          className="mt-[var(--spacing-xs)]"
          onClick={() => navigate("/journey/cadence")}
        >
          {c.skipHealth}
        </Button>
      ) : null}
    </Screen>
  );
}
