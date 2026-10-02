import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { JOURNEY } from "@/copy/journey";
import { SAFETY } from "@/copy/safety";

/** Icons for intro cards - matching the widget icon design style */
function HomeIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M12 3L4 9v12h5v-7h6v7h5V9l-8-6z" />
    </svg>
  );
}

function TechniqueIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
      <circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" strokeWidth="2" />
      <path d="M9 12l2 2 4-4" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function EducationIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M12 3L1 9l11 6 9-4.91V17h2V9L12 3z" />
      <path d="M5 13.18v4L12 21l7-3.82v-4L12 17l-7-3.82z" />
    </svg>
  );
}

const INTRO_ICONS = [HomeIcon, TechniqueIcon, EducationIcon];

/**
 * Journey step 1 — educate. Reached from the landing screen.
 *
 * Icon + text rows without white card boxes, matching the widget icon design.
 */
export function Intro() {
  const navigate = useNavigate();
  const c = JOURNEY.intro;

  return (
    <Screen
      overline={c.eyebrow}
      title={c.title}
      className="step-enter"
      footer={<Button onClick={() => navigate("/journey/signup")}>{c.cta}</Button>}
    >
      <StepDots total={5} current={1} />

      <p
        className="pb-[var(--spacing-md)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-base)", lineHeight: "var(--leading-body)" }}
      >
        {c.intro}
      </p>

      <div className="flex flex-col gap-[var(--spacing-md)]">
        {c.cards.map((card, i) => {
          const Icon = INTRO_ICONS[i] ?? HomeIcon;
          return (
            <div key={card.title} className="flex items-start gap-[var(--spacing-sm)]">
              <span className="mt-[2px] flex-none text-heading">
                <Icon />
              </span>
              <div className="min-w-0">
                <h2
                  style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}
                >
                  {card.title}
                </h2>
                <p
                  className="pt-[var(--spacing-3xs)] text-ink-secondary"
                  style={{ fontSize: "var(--text-body-sm)" }}
                >
                  {card.body}
                </p>
              </div>
            </div>
          );
        })}
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
