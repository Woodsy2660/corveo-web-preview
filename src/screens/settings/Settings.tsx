import { useEffect, useState } from "react";
import { useNavigate } from "react-router";
import { Link } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Card } from "@/components/ui/Card";
import { Button } from "@/components/ui/Button";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { HEALTH_SYNC } from "@/copy/health-sync";
import { SAFETY, VALIDATED_CUFFS } from "@/copy/safety";
import { getApi, resetApi } from "@/lib/api";
import { useConsentStatus } from "@/lib/api/hooks";
import { getHealthPlugin, resetHealthPlugin, type AuthorizationState } from "@/lib/health";
import { useJourney } from "@/lib/journey/state";
import { fmtFullDate } from "@/lib/format";
import { useQueryClient } from "@tanstack/react-query";

/**
 * Settings — Apple Health status, export and deletion (Deliverable 12),
 * consent receipt, the safety surface, and the dev-only demo reset.
 */
export function Settings() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { data: consent } = useConsentStatus();
  const { resetJourney } = useJourney();
  const [health, setHealth] = useState<AuthorizationState | null>(null);
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [exporting, setExporting] = useState(false);
  const c = APP.settings;

  useEffect(() => {
    void getHealthPlugin().getAuthorizationState().then(setHealth);
  }, []);

  const exportData = async () => {
    setExporting(true);
    try {
      // On device this hands the files to the iOS share sheet (docs/02 §4.4).
      const result = await getApi().exportPatientData();
      const blob = new Blob([result.csv], { type: "text/csv" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "corveo-my-heart-record.csv";
      a.click();
      URL.revokeObjectURL(url);
    } finally {
      setExporting(false);
    }
  };

  const requestDeletion = async () => {
    await getApi().requestAccountDeletion();
    resetJourney();
    resetHealthPlugin();
    await qc.invalidateQueries();
    navigate("/journey/welcome", { replace: true });
  };

  const resetDemo = async () => {
    resetApi();
    resetHealthPlugin();
    resetJourney();
    qc.clear();
    navigate("/journey/welcome", { replace: true });
  };

  const connected = health?.state === "requested";

  return (
    <Screen
      eyebrow={c.eyebrow}
      title={c.title}
      footer={
        <Button variant="ghost" onClick={() => navigate(-1)}>
          {APP.common.back}
        </Button>
      }
    >
      <div className="flex flex-col gap-[var(--spacing-sm)]">
        <Card label={c.appleHealth.title}>
          <p style={{ fontSize: "var(--text-body-sm)" }}>
            {connected ? c.appleHealth.readsOnly : c.appleHealth.notConnected}
          </p>
          {connected && health && !health.samplesEverReceived ? (
            // Neutral nudge, verbatim from docs/03 §4 — absence of data is
            // indistinguishable from denial, and we never imply denial.
            <p className="pt-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-body-sm)" }}>
              {JOURNEY.healthAuth.noSamplesNudge}
            </p>
          ) : null}
          <p className="pt-[var(--spacing-3xs)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
            {c.appleHealth.manageHint}
          </p>
        </Card>

        <Card label={c.yourData.title}>
          <p className="pb-[var(--spacing-sm)]" style={{ fontSize: "var(--text-body-sm)" }}>
            {c.yourData.body}
          </p>
          <div className="flex flex-col gap-[var(--spacing-2xs)]">
            <Button variant="secondary" disabled={exporting} onClick={exportData}>
              {exporting ? APP.common.busy : c.yourData.exportCta}
            </Button>
            <p className="text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
              {c.yourData.exportNote}
            </p>

            {confirmingDelete ? (
              <div className="rounded-md border border-hairline p-[var(--spacing-sm)]">
                <h3 className="pb-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-heading-xl)" }}>
                  {c.yourData.deleteConfirmTitle}
                </h3>
                <p className="pb-[var(--spacing-sm)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
                  {c.yourData.deleteConfirmBody}
                </p>
                <div className="flex flex-col gap-[var(--spacing-2xs)]">
                  <Button onClick={requestDeletion}>{c.yourData.deleteConfirmCta}</Button>
                  <Button variant="secondary" onClick={() => setConfirmingDelete(false)}>
                    {c.yourData.deleteCancelCta}
                  </Button>
                </div>
              </div>
            ) : (
              <Button variant="secondary" onClick={() => setConfirmingDelete(true)}>
                {c.yourData.deleteCta}
              </Button>
            )}
          </div>
          {consent?.has_active_consent && consent.version && consent.last_event_at ? (
            <p className="pt-[var(--spacing-sm)] text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
              {c.yourData.consentReceipt(consent.version, fmtFullDate(consent.last_event_at))}
            </p>
          ) : null}
        </Card>

        {/*
         * The safety surface (Deliverable 12) and the validated-monitor list
         * (Deliverable 8) live here: "about this app" is account-adjacent
         * reference, and the Learn tab is the publication only. This reverses
         * the earlier move to Education — the Stage 2 and Stage 3 test
         * scripts reference their location and need updating.
         */}
        <Card label={c.aboutTitle}>
          <h2 className="pb-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-heading-xl)" }}>
            {SAFETY.title}
          </h2>

          <p className="eyebrow pb-[var(--spacing-3xs)]">{SAFETY.does.title}</p>
          <ul
            className="list-disc pb-[var(--spacing-xs)] pl-[var(--spacing-sm)] text-ink-secondary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {SAFETY.does.items.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>

          <p className="eyebrow pb-[var(--spacing-3xs)]">{SAFETY.doesNot.title}</p>
          <ul
            className="list-disc pb-[var(--spacing-xs)] pl-[var(--spacing-sm)] text-ink-secondary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {SAFETY.doesNot.items.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>

          <p className="pb-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-body-sm)" }}>
            {SAFETY.seekAdvice}
          </p>
          <p className="text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
            {SAFETY.disclaimer}
          </p>
        </Card>

        <Card label={c.cuffsTitle}>
          <p
            className="pb-[var(--spacing-xs)] text-ink-secondary"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {VALIDATED_CUFFS.intro}
          </p>
          <Link
            to="/app/cuffs"
            className="underline underline-offset-4"
            style={{ fontSize: "var(--text-body-sm)" }}
          >
            {VALIDATED_CUFFS.title}
          </Link>
        </Card>

        {import.meta.env.DEV || import.meta.env.VITE_DEMO === "true" ? (
          <Card label={c.demo.title}>
            <Button variant="secondary" onClick={resetDemo}>
              {c.demo.resetCta}
            </Button>
            <p className="pt-[var(--spacing-2xs)] text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
              {c.demo.note}
            </p>
          </Card>
        ) : null}

        {/*
         * Quiet entry to the presentation. Deliberately the last thing on the
         * last screen: a patient never needs it, and anyone being walked
         * through the build will be shown where it is.
         */}
        <button
          onClick={() => navigate("/behind")}
          className="pt-[var(--spacing-2xs)] pb-[var(--spacing-md)] text-center text-ink-tertiary underline underline-offset-4"
          style={{ fontSize: "var(--text-label)" }}
        >
          {HEALTH_SYNC.behindLink}
        </button>
      </div>
    </Screen>
  );
}
