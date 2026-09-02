import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { JOURNEY } from "@/copy/journey";
import { SAFETY } from "@/copy/safety";

/** Journey step 1 — educate. Reached from the landing screen. */
export function Intro() {
  const navigate = useNavigate();
  const c = JOURNEY.intro;

  return (
    <Screen
      eyebrow={c.eyebrow}
      title={c.title}
      footer={<Button onClick={() => navigate("/journey/signup")}>{c.cta}</Button>}
    >
      <StepDots total={5} current={1} />
      <p className="pb-[var(--spacing-md)] text-ink-secondary">{c.intro}</p>

      <div className="flex flex-col gap-[var(--spacing-xs)]">
        {c.cards.map((card) => (
          <Card key={card.title}>
            <h2 className="pb-[var(--spacing-3xs)]" style={{ fontSize: "var(--text-heading-xl)" }}>
              {card.title}
            </h2>
            <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
              {card.body}
            </p>
          </Card>
        ))}
      </div>

      <p
        className="pt-[var(--spacing-md)] text-ink-tertiary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {SAFETY.disclaimer}
      </p>
    </Screen>
  );
}
