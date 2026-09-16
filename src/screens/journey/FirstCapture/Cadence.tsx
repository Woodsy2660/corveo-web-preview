import React from "react";
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
    navigate("/app/record", { replace: true });
  };

  return (
    <Screen
      overline={c.eyebrow}
      title={c.title}
      className="step-enter"
      footer={
        <Button disabled={!cadence || updateProgress.isPending} onClick={finish}>
          {c.cta}
        </Button>
      }
    >
      <StepDots total={5} current={5} />
      <p
        className="pb-[var(--spacing-lg)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-body-relaxed)" }}
      >
        {c.intro}
      </p>

      <div className="flex flex-col" role="radiogroup" aria-label={c.title}>
        {ORDER.map((key, i) => {
          const opt = c.options[key];
          const selected = cadence === key;
          return (
            <button
              key={key}
              role="radio"
              aria-checked={selected}
              onClick={() => setCadence(key)}
              className={`card-enter flex items-start gap-[var(--spacing-sm)] border-b border-hairline py-[var(--spacing-sm)] text-left ${
                i === 0 ? "border-t" : ""
              }`}
              style={{ "--stagger-index": i } as React.CSSProperties}
            >
              {/* Radio dot */}
              <span
                className="mt-[3px] flex size-[20px] flex-none items-center justify-center rounded-round border-2"
                style={{
                  borderColor: selected ? "var(--app-heading)" : "var(--app-hairline)",
                  transitionProperty: "border-color",
                  transitionDuration: "var(--duration-fast)",
                }}
              >
                {selected ? (
                  <span
                    className="block size-[10px] rounded-round bg-heading"
                  />
                ) : null}
              </span>

              <div className="min-w-0">
                <span
                  className={selected ? "text-heading" : ""}
                  style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}
                >
                  {opt.title}
                </span>
                {/* Body text reveals only on selection — progressive disclosure */}
                {selected ? (
                  <p
                    className="expand-enter pt-[var(--spacing-3xs)] text-ink-secondary"
                    style={{ fontSize: "var(--text-body-sm)", lineHeight: "var(--leading-body)" }}
                  >
                    {opt.body}
                  </p>
                ) : null}
              </div>
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
