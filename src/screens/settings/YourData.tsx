import { useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { APP } from "@/copy/app";
import { getApi, resetApi } from "@/lib/api";
import { useConsentStatus } from "@/lib/api/hooks";
import { resetHealthPlugin } from "@/lib/health";
import { useJourney } from "@/lib/journey/state";
import { fmtFullDate } from "@/lib/format";
import { useQueryClient } from "@tanstack/react-query";

/**
 * Your data: export and deletion (Deliverable 12) and the consent receipt,
 * on their own page under Settings. Deletion is deletion-with-logging
 * against the retention floor (SOW A.12.6), never an unconditional wipe.
 */
export function YourData() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const { data: consent } = useConsentStatus();
  const { resetJourney } = useJourney();
  const [confirmingDelete, setConfirmingDelete] = useState(false);
  const [exporting, setExporting] = useState(false);
  const c = APP.settings.yourData;

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

  const resetDemo = async () => {
    resetApi();
    resetHealthPlugin();
    resetJourney();
    qc.clear();
    navigate("/journey/welcome", { replace: true });
  };

  const requestDeletion = async () => {
    await getApi().requestAccountDeletion();
    resetJourney();
    resetHealthPlugin();
    await qc.invalidateQueries();
    navigate("/journey/welcome", { replace: true });
  };

  return (
    <Screen
      title={c.title}
      footer={
        <Button variant="ghost" onClick={() => navigate(-1)}>
          {APP.common.back}
        </Button>
      }
    >
      <p className="pb-[var(--spacing-md)] text-ink-secondary">{c.body}</p>

      <div className="flex flex-col gap-[var(--spacing-2xs)]">
        <Button variant="secondary" disabled={exporting} onClick={exportData}>
          {exporting ? APP.common.busy : c.exportCta}
        </Button>
        <p className="pb-[var(--spacing-xs)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {c.exportNote}
        </p>

        {confirmingDelete ? (
          <div className="rounded-md border border-hairline p-[var(--spacing-sm)]">
            <h2 className="pb-[var(--spacing-2xs)]" style={{ fontSize: "var(--text-heading-xl)" }}>
              {c.deleteConfirmTitle}
            </h2>
            <p className="pb-[var(--spacing-sm)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
              {c.deleteConfirmBody}
            </p>
            <div className="flex flex-col gap-[var(--spacing-2xs)]">
              <Button onClick={requestDeletion}>{c.deleteConfirmCta}</Button>
              <Button variant="secondary" onClick={() => setConfirmingDelete(false)}>
                {c.deleteCancelCta}
              </Button>
            </div>
          </div>
        ) : (
          <Button variant="secondary" onClick={() => setConfirmingDelete(true)}>
            {c.deleteCta}
          </Button>
        )}
      </div>

      {consent?.has_active_consent && consent.version && consent.last_event_at ? (
        <p className="pt-[var(--spacing-md)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {c.consentReceipt(consent.version, fmtFullDate(consent.last_event_at))}
        </p>
      ) : null}

      {import.meta.env.DEV || import.meta.env.VITE_DEMO === "true" ? (
        <section aria-label={APP.settings.demo.title} className="pt-[var(--spacing-lg)]">
          <p className="eyebrow pb-[var(--spacing-2xs)]">{APP.settings.demo.title}</p>
          <Button variant="secondary" onClick={resetDemo}>
            {APP.settings.demo.resetCta}
          </Button>
          <p className="pt-[var(--spacing-2xs)] text-ink-tertiary" style={{ fontSize: "var(--text-label)" }}>
            {APP.settings.demo.note}
          </p>
        </section>
      ) : null}
    </Screen>
  );
}
