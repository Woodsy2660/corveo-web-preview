import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { JOURNEY } from "@/copy/journey";
import { useJourney, type CadenceChoice } from "@/lib/journey/state";
import { useUpdateProgress } from "@/lib/api/hooks";

const ORDER: CadenceChoice[] = ["twice_daily", "daily", "few_weekly"];

/**
 * Journey step 5 — cadence. Reminders (local notifications, wired in the
 * native shell) follow this chosen rhythm only; they are never triggered by
 * a reading's value (SOW A.3.3).
 */
export function Cadence() {
  const navigate = useNavigate();
  const { cadence, setCadence, completeJourney } = useJourney();
  const updateProgress = useUpdateProgress();
  const c = JOURNEY.cadence;

  const finish = async () => {
    await updateProgress.mutateAsync({ current_week: 1, completed_steps: { journey: true } });
    completeJourney();
    navigate("/app/readings", { replace: true });
  };

  return (
    <Screen
      eyebrow={c.eyebrow}
      title={c.title}
      footer={
        <Button disabled={!cadence || updateProgress.isPending} onClick={finish}>
          {c.cta}
        </Button>
      }
    >
      <StepDots total={5} current={5} />
      <p className="pb-[var(--spacing-md)] text-ink-secondary">{c.intro}</p>

      <div className="flex flex-col gap-[var(--spacing-xs)]" role="radiogroup" aria-label={c.title}>
        {ORDER.map((key) => {
          const opt = c.options[key];
          const selected = cadence === key;
          return (
            <button
              key={key}
              role="radio"
              aria-checked={selected}
              onClick={() => setCadence(key)}
              className={`rounded-lg bg-card p-[var(--spacing-sm)] text-left ${
                selected ? "ring-2 ring-black" : "ring-1 ring-transparent"
              }`}
            >
              <span className="block pb-[var(--spacing-3xs)]" style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}>
                {opt.title}
              </span>
              <span className="block text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
                {opt.body}
              </span>
            </button>
          );
        })}
      </div>

      <p className="pt-[var(--spacing-md)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
        {c.reminderNote}
      </p>
    </Screen>
  );
}
