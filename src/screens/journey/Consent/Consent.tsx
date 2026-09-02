import { useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { StepDots } from "@/components/ui/StepDots";
import { APP } from "@/copy/app";
import { CONSENT, CONSENT_VERSION, hashConsentText } from "@/copy/consent";
import { useRecordConsent } from "@/lib/api/hooks";

/**
 * Express-consent step (Deliverable 5 + 13; Stage 3 acceptance (b)).
 *
 * Writes an evidence-grade consent event: version + SHA-256 of the exact
 * text shown + timestamp, via the consent API. UI ordering is not the
 * enforcement — the ingest path gates on consent server-side.
 */
export function Consent() {
  const navigate = useNavigate();
  const [agreed, setAgreed] = useState(false);
  const recordConsent = useRecordConsent();

  const onConsent = async () => {
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
      footer={
        <Button disabled={!agreed || recordConsent.isPending} onClick={onConsent}>
          {recordConsent.isPending ? APP.common.busy : CONSENT.cta}
        </Button>
      }
    >
      <StepDots total={5} current={2} />
      <p className="pb-[var(--spacing-md)] text-ink-secondary">{CONSENT.intro}</p>

      <div className="flex flex-col gap-[var(--spacing-xs)]">
        {CONSENT.points.map((p) => (
          <Card key={p.title}>
            <h2 className="pb-[var(--spacing-3xs)]" style={{ fontSize: "var(--text-heading-xl)" }}>
              {p.title}
            </h2>
            <p className="text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
              {p.body}
            </p>
          </Card>
        ))}
      </div>

      <label className="flex items-start gap-[var(--spacing-xs)] pt-[var(--spacing-md)]">
        <input
          type="checkbox"
          checked={agreed}
          onChange={(e) => setAgreed(e.target.checked)}
          className="mt-[4px] size-[18px] accent-heading"
        />
        <span style={{ fontSize: "var(--text-body-sm)" }}>{CONSENT.checkboxLabel}</span>
      </label>
    </Screen>
  );
}
