import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { useJourney, type CadenceChoice } from "@/lib/journey/state";

const ORDER: CadenceChoice[] = ["twice_daily", "daily", "few_weekly"];

/**
 * Reminder rhythm, from Settings. Same choices as the journey cadence
 * step; a tap writes the choice immediately. Reminders follow this rhythm
 * only — they are never triggered by a reading's value (SOW A.3.3).
 */
export function Reminder() {
  const navigate = useNavigate();
  const { cadence, setCadence } = useJourney();
  const page = APP.settings.reminder;
  const c = JOURNEY.cadence;

  return (
    <Screen
      title={page.title}
      footer={
        <Button variant="ghost" onClick={() => navigate(-1)}>
          {APP.common.back}
        </Button>
      }
    >
      <p
        className="pb-[var(--spacing-lg)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-body-relaxed)" }}
      >
        {page.intro}
      </p>

      <div className="flex flex-col" role="radiogroup" aria-label={page.title}>
        {ORDER.map((key, i) => {
          const opt = c.options[key];
          const selected = cadence === key;
          return (
            <button
              key={key}
              role="radio"
              aria-checked={selected}
              onClick={() => setCadence(key)}
              className={`flex items-start gap-[var(--spacing-sm)] border-b border-hairline py-[var(--spacing-sm)] text-left ${
                i === 0 ? "border-t" : ""
              }`}
            >
              <span
                className="mt-[3px] flex size-[20px] flex-none items-center justify-center rounded-round border-2"
                style={{
                  borderColor: selected ? "var(--app-heading)" : "var(--app-hairline)",
                }}
              >
                {selected ? <span className="block size-[10px] rounded-round bg-heading" /> : null}
              </span>
              <div className="min-w-0">
                <span
                  className={selected ? "text-heading" : ""}
                  style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}
                >
                  {opt.title}
                </span>
                {selected ? (
                  <p
                    className="pt-[var(--spacing-3xs)] text-ink-secondary"
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
