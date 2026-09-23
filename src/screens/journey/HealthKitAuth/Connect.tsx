import React, { useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { ChevronDownIcon } from "@/components/ui/icons";
import { JOURNEY } from "@/copy/journey";
import { ValidatedCuffList } from "@/components/ui/ValidatedCuffList";
import { useJourney, type ConnectChoice } from "@/lib/journey/state";

const ORDER: ConnectChoice[] = ["healthkit", "manual", "none"];

/**
 * Journey step 3 — connect: cuff / manual / none branch.
 *
 * Minimal buttons: just the title, a radio dot on the left, and
 * the body text appears only under the selected option. Clean,
 * quiet, no icons, no card containers. The cuff list uses the
 * same hairline-separated, radio-dot aesthetic.
 */
export function Connect() {
  const navigate = useNavigate();
  const { connectChoice, setConnectChoice } = useJourney();
  const [cuffsOpen, setCuffsOpen] = useState(false);
  const c = JOURNEY.connect;

  const next = () =>
    navigate(connectChoice === "healthkit" ? "/journey/health-auth" : "/journey/capture");

  return (
    <Screen
      overline={c.eyebrow}
      title={c.title}
      className="step-enter"
      footer={
        <Button disabled={!connectChoice} onClick={next}>
          {c.cta}
        </Button>
      }
    >
      <StepDots total={5} current={3} />

      <p
        className="pb-[var(--spacing-lg)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-body-relaxed)" }}
      >
        {c.intro}
      </p>

      <div className="flex flex-col" role="radiogroup" aria-label={c.title}>
        {ORDER.map((key, i) => {
          const opt = c.options[key];
          const selected = connectChoice === key;
          return (
            <button
              key={key}
              role="radio"
              aria-checked={selected}
              onClick={() => setConnectChoice(key)}
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

      {connectChoice === "none" ? (
        <div className="expand-enter pt-[var(--spacing-sm)]">
          <button
            type="button"
            onClick={() => setCuffsOpen((v) => !v)}
            aria-expanded={cuffsOpen}
            className="flex w-full items-center justify-between py-[var(--spacing-xs)] text-left"
          >
            <span
              className="text-ink-secondary underline underline-offset-4"
              style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}
            >
              {c.cuffsLink}
            </span>
            <span
              className="flex-none text-ink-tertiary"
              style={{
                fontSize: "var(--text-body-sm)",
                transform: cuffsOpen ? "rotate(180deg)" : "rotate(0deg)",
                transition: "transform var(--duration-fast) var(--ease-brand)",
              }}
            >
              <ChevronDownIcon />
            </span>
          </button>
          {cuffsOpen ? (
            <div className="expand-enter pb-[var(--spacing-xs)]">
              <ValidatedCuffList />
            </div>
          ) : null}
        </div>
      ) : null}
    </Screen>
  );
}
