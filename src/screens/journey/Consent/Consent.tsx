import React, { useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { APP } from "@/copy/app";
import { CONSENT, CONSENT_VERSION, hashConsentText } from "@/copy/consent";
import { useRecordConsent } from "@/lib/api/hooks";
import {
  ClipboardSolidIcon,
  LockSolidIcon,
  EyeSolidIcon,
  ShieldSolidIcon,
} from "@/components/ui/icons";

const POINT_ICONS: (() => React.ReactNode)[] = [
  () => <ClipboardSolidIcon />,
  () => <LockSolidIcon />,
  () => <EyeSolidIcon />,
  () => <ShieldSolidIcon />,
];

/**
 * Express-consent step (Deliverable 5 + 13; Stage 3 acceptance (b)).
 *
 * Same layout pattern as the Intro screen: icon box + title + one-line
 * summary for each consent point, keeping the visual language consistent
 * across the journey. The body text of each point is the sub line.
 *
 * Not floating — user scrolls to the checkbox and CTA. Tapping consent
 * without checking the box shows an inline nudge.
 *
 * Every hashed word is rendered.
 */
export function Consent() {
  const navigate = useNavigate();
  const [agreed, setAgreed] = useState(false);
  const [nudge, setNudge] = useState(false);
  const recordConsent = useRecordConsent();

  const onConsent = async () => {
    if (!agreed) {
      setNudge(true);
      return;
    }
    setNudge(false);
    const document_hash = await hashConsentText();
    await recordConsent.mutateAsync({
      action: "granted",
      version: CONSENT_VERSION,
      document_hash,
      method: "in_app_explicit",
    });
    navigate("/journey/connect");
  };

  return (
    <Screen
      overline={CONSENT.eyebrow}
      title={CONSENT.title}
      className="step-enter"
    >
      <StepDots total={5} current={2} />

      <p
        className="pb-[var(--spacing-lg)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-lg)", lineHeight: "var(--leading-body-relaxed)" }}
      >
        {CONSENT.intro}
      </p>

      <div className="flex flex-col gap-[var(--spacing-md)]">
        {CONSENT.points.map((p, i) => {
          const Icon = POINT_ICONS[i] ?? (() => null);
          return (
            <div
              key={p.title}
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
                  {p.title}
                </h2>
                <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
                  {p.body}
                </p>
              </div>
            </div>
          );
        })}
      </div>

      {/* Checkbox — must scroll to reach */}
      <label className="flex items-start gap-[var(--spacing-xs)] pt-[var(--spacing-lg)] min-h-[48px]">
        <span className="flex size-[48px] flex-none items-center justify-center -m-[15px] mr-[calc(var(--spacing-xs)-15px)]">
          <input
            type="checkbox"
            checked={agreed}
            onChange={(e) => { setAgreed(e.target.checked); setNudge(false); }}
            className="size-[22px] accent-heading"
          />
        </span>
        <span style={{ fontSize: "var(--text-body-sm)", lineHeight: "var(--leading-body)" }}>
          {CONSENT.checkboxLabel}
        </span>
      </label>

      {nudge ? (
        <p
          className="pt-[var(--spacing-xs)] text-ink-secondary"
          role="alert"
          style={{ fontSize: "var(--text-body-sm)" }}
        >
          Please read and check the box above before continuing.
        </p>
      ) : null}

      <div className="pt-[var(--spacing-md)] pb-[var(--spacing-sm)]">
        <Button disabled={recordConsent.isPending} onClick={onConsent}>
          {recordConsent.isPending ? APP.common.busy : CONSENT.cta}
        </Button>
      </div>
    </Screen>
  );
}
