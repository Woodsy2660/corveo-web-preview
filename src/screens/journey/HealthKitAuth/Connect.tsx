import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { JOURNEY } from "@/copy/journey";
import { VALIDATED_CUFFS } from "@/copy/safety";
import { useJourney, type ConnectChoice } from "@/lib/journey/state";

const ORDER: ConnectChoice[] = ["healthkit", "manual", "none"];

/** Journey step 3 — connect: cuff / manual / none branch. */
export function Connect() {
  const navigate = useNavigate();
  const { connectChoice, setConnectChoice } = useJourney();
  const c = JOURNEY.connect;

  const next = () =>
    navigate(connectChoice === "healthkit" ? "/journey/health-auth" : "/journey/capture");

  return (
    <Screen
      overline={c.eyebrow}
      title={c.title}
      footer={
        <Button disabled={!connectChoice} onClick={next}>
          {c.cta}
        </Button>
      }
    >
      <StepDots total={5} current={3} />
      <p className="pb-[var(--spacing-md)] text-ink-secondary">{c.intro}</p>

      <div className="flex flex-col gap-[var(--spacing-xs)]" role="radiogroup" aria-label={c.title}>
        {ORDER.map((key) => {
          const opt = c.options[key];
          const selected = connectChoice === key;
          return (
            <button
              key={key}
              role="radio"
              aria-checked={selected}
              onClick={() => setConnectChoice(key)}
              className={`rounded-lg bg-card p-[var(--spacing-sm)] text-left transition-shadow ${
                selected ? "ring-2 ring-heading" : "ring-1 ring-transparent"
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

      {connectChoice === "none" ? (
        <Card label={VALIDATED_CUFFS.eyebrow} className="mt-[var(--spacing-sm)]">
          <p className="pb-[var(--spacing-xs)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
            {VALIDATED_CUFFS.intro}
          </p>
          <ul className="flex flex-col gap-[var(--spacing-2xs)]">
            {VALIDATED_CUFFS.devices.map((d) => (
              <li key={d.model} style={{ fontSize: "var(--text-body-sm)" }}>
                <span style={{ fontWeight: 500 }}>
                  {d.brand} {d.model}
                </span>
                <span className="block text-ink-tertiary">{d.connectivity}</span>
              </li>
            ))}
          </ul>
          <p className="pt-[var(--spacing-xs)] text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
            {VALIDATED_CUFFS.sourceNote}
          </p>
        </Card>
      ) : null}
    </Screen>
  );
}
