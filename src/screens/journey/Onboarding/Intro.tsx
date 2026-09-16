import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import React from "react";
import { HeartSolidIcon, BookSolidIcon, CheckCircleSolidIcon } from "@/components/ui/icons";
import { JOURNEY } from "@/copy/journey";
import { SAFETY } from "@/copy/safety";

const ICONS: Record<string, () => React.ReactNode> = {
  home: () => <HeartSolidIcon />,
  technique: () => <CheckCircleSolidIcon />,
  education: () => <BookSolidIcon />,
};

/**
 * Journey step 1 — educate. Reached from the landing screen.
 *
 * Redesigned for the 60+ audience: the dense three-card wall is
 * replaced with a clean highlight list — icon, title, one-line
 * subtitle. No expandables needed because the content is short enough
 * to read without scrolling. The full education detail lives in the
 * six-week program itself; this screen sets expectations, not curriculum.
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
        className="pb-[var(--spacing-lg)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-body-relaxed)" }}
      >
        {c.intro}
      </p>

      <div className="flex flex-col gap-[var(--spacing-md)]">
        {c.highlights.map((h, i) => {
          const Icon = ICONS[h.icon] ?? (() => null);
          return (
            <div
              key={h.title}
              className="card-enter flex items-start gap-[var(--spacing-sm)]"
              style={{ "--stagger-index": i } as React.CSSProperties}
            >
              <span
                className="flex flex-none items-center justify-center text-heading"
                style={{ fontSize: "20px", width: "24px", marginTop: "2px" }}
              >
                <Icon />
              </span>
              <div>
                <h2 style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}>
                  {h.title}
                </h2>
                <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
                  {h.sub}
                </p>
              </div>
            </div>
          );
        })}
      </div>

      <p
        className="pt-[var(--spacing-lg)] text-ink-tertiary"
        style={{ fontSize: "var(--text-label)" }}
      >
        {SAFETY.disclaimer}
      </p>
    </Screen>
  );
}
