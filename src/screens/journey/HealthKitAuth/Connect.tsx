import React from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { Card } from "@/components/ui/Card";
import { JOURNEY } from "@/copy/journey";
import { useJourney, type ConnectChoice } from "@/lib/journey/state";
import { VALIDATED_CUFFS } from "@/copy/validated-cuffs";

const ORDER: ConnectChoice[] = ["healthkit", "manual", "none"];

/**
 * Journey step 3 — connect: cuff / manual / none branch.
 *
 * Circular radio buttons with title + body text.
 */
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
      className="step-enter"
      footer={
        <Button disabled={!connectChoice} onClick={next}>
          {c.cta}
        </Button>
      }
    >
      <StepDots total={5} current={3} />

      <p
        className="pb-[var(--spacing-md)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-base)", lineHeight: "var(--leading-body)" }}
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
              type="button"
              role="radio"
              aria-checked={selected}
              onClick={() => setConnectChoice(key)}
              className={`card-enter flex items-start gap-[var(--spacing-sm)] border-b border-hairline py-[var(--spacing-sm)] text-left ${
                i === 0 ? "border-t" : ""
              }`}
              style={{ "--stagger-index": i } as React.CSSProperties}
            >
              {/* Circular radio button */}
              <span
                className="mt-[3px] flex size-[20px] flex-none items-center justify-center rounded-full border-2"
                style={{
                  borderColor: selected ? "var(--app-heading)" : "var(--app-hairline)",
                  transitionProperty: "border-color",
                  transitionDuration: "var(--duration-fast)",
                }}
              >
                {selected ? (
                  <span className="block size-[10px] rounded-full bg-heading" />
                ) : null}
              </span>

              <div className="min-w-0">
                <span
                  className={selected ? "text-heading" : ""}
                  style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}
                >
                  {opt.title}
                </span>
                <p
                  className="pt-[var(--spacing-3xs)] text-ink-secondary"
                  style={{ fontSize: "var(--text-body-sm)", lineHeight: "var(--leading-body)" }}
                >
                  {opt.body}
                </p>
              </div>
            </button>
          );
        })}
      </div>

      {/* Validated cuffs card shown when "none" is selected */}
      {connectChoice === "none" ? (
        <Card label={c.cuffsLink} className="expand-enter mt-[var(--spacing-sm)]">
          <p
            className="pb-[var(--spacing-xs)] text-ink-secondary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {VALIDATED_CUFFS.intro}
          </p>
          <div className="flex flex-col gap-[var(--spacing-xxs)]">
            {VALIDATED_CUFFS.devices.map((d) => (
              <div key={d.model}>
                <p style={{ fontSize: "var(--text-body-sm)", fontWeight: 500 }}>
                  {d.brand} {d.model}
                </p>
                <p
                  className="text-ink-tertiary"
                  style={{ fontSize: "var(--text-body-sm)" }}
                >
                  {d.connectivity}
                </p>
              </div>
            ))}
          </div>
          <p
            className="pt-[var(--spacing-xs)] text-ink-tertiary"
            style={{ fontSize: "var(--text-label)" }}
          >
            {VALIDATED_CUFFS.sourceNote}
          </p>
        </Card>
      ) : null}
    </Screen>
  );
}
