import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { ManualEntryForm } from "@/components/ManualEntryForm";
import { JOURNEY } from "@/copy/journey";
import { useJourney } from "@/lib/journey/state";

/**
 * Journey step 4 — first capture.
 *
 * Synced from ios/BPReset/Features/Journey/JourneyViews.swift FirstCaptureView.
 * A visible way past this step: a reading is never required to finish onboarding,
 * so nobody without a monitor has to invent one (rulebook 5.1.1; the record holds
 * only what was measured).
 */
export function FirstCapture() {
  const navigate = useNavigate();
  const { connectChoice } = useJourney();
  const c = JOURNEY.firstCapture;

  // Skip text differs by connect choice
  const skipText = connectChoice === "healthkit" ? c.skipHealth : c.skip;

  return (
    <Screen
      overline={c.eyebrow}
      title={c.title}
      className="step-enter"
      footer={
        <Button variant="ghost" onClick={() => navigate("/journey/cadence")}>
          {skipText}
        </Button>
      }
    >
      <StepDots total={5} current={4} />
      <p
        className="pb-[var(--spacing-md)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-base)", lineHeight: "var(--leading-body)" }}
      >
        {c.intro}
      </p>

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
