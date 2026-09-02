import { useEffect, useState } from "react";
import { useNavigate } from "react-router";
import { Screen } from "@/components/ui/Screen";
import { Button } from "@/components/ui/Button";
import { AppleHealthSheet } from "@/components/ui/AppleHealthSheet";
import { CheckIcon, SyncIcon } from "@/components/ui/icons";
import { APP } from "@/copy/app";
import { JOURNEY } from "@/copy/journey";
import { CORVEO_WORDMARK } from "@/copy/product";
import { getHealthPlugin } from "@/lib/health";
import { setStoreReadable } from "@/lib/health/demo";
import { useAppleHealthSync } from "@/lib/health/useAppleHealthSync";

/**
 * Apple Health, on its own page under Settings: whether it is connected,
 * when the app last looked, a way to look now, and a way to pause and
 * resume the looking. Connecting runs the same request as the journey.
 *
 * What it never says: that permission was refused. The app is not told
 * (docs/03 §4), so "connected" means the request was made, and an empty
 * record reads as empty, never as denied. Access itself is managed in iOS
 * Settings, which is where the page points.
 */
export function AppleHealth() {
  const navigate = useNavigate();
  const c = APP.settings.appleHealth;
  const health = useAppleHealthSync();
  const [observing, setObserving] = useState<boolean | null>(null);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void getHealthPlugin()
      .getSyncStatus()
      .then((s) => setObserving(s.observing));
  }, [health.active]);

  const connect = async (readable: boolean) => {
    setSheetOpen(false);
    setBusy(true);
    try {
      // Demo only: tells the simulated Health store whether it will hand
      // anything over. The plugin is not told, and cannot be.
      setStoreReadable(readable);
      const plugin = getHealthPlugin();
      await plugin.requestAuthorization();
      await plugin.startObserving();
      await health.refresh();
    } finally {
      setBusy(false);
    }
  };

  const setPaused = async (paused: boolean) => {
    setBusy(true);
    try {
      const plugin = getHealthPlugin();
      if (paused) await plugin.stopObserving();
      else await plugin.startObserving();
      setObserving(!paused);
    } finally {
      setBusy(false);
    }
  };

  const rows: [string, string][] = [
    [c.statusLabel, observing === false ? c.paused : c.connected],
    [c.lastLookedLabel, health.status ?? ""],
  ];

  return (
    <>
      <Screen
        title={c.title}
        footer={
          <Button variant="ghost" onClick={() => navigate(-1)}>
            {APP.common.back}
          </Button>
        }
      >
        {health.active ? (
          <>
            <dl className="m-0 flex flex-col pb-[var(--spacing-md)]">
              {rows.map(([label, value]) => (
                <div
                  key={label}
                  className="flex items-baseline justify-between gap-[var(--spacing-sm)] border-b border-hairline py-[var(--spacing-2xs)]"
                >
                  <dt className="text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
                    {label}
                  </dt>
                  <dd
                    aria-live="polite"
                    className="m-0 text-right"
                    style={{
                      fontSize: "var(--text-body-sm)",
                      color: health.arrived ? "var(--color-surface-color-1)" : undefined,
                    }}
                  >
                    {value}
                  </dd>
                </div>
              ))}
            </dl>

            <p className="pb-[var(--spacing-md)] text-ink-secondary">{c.readsOnly}</p>

            <div className="flex flex-col gap-[var(--spacing-2xs)]">
              <Button
                variant="secondary"
                disabled={busy || health.phase === "busy" || observing === false}
                onClick={health.sync}
              >
                <span className="inline-flex items-center gap-[var(--spacing-2xs)]">
                  <span className={`flex size-[15px] items-center justify-center ${health.phase === "busy" ? "spin" : ""}`}>
                    {health.phase === "done" ? <CheckIcon /> : <SyncIcon />}
                  </span>
                  {health.label}
                </span>
              </Button>
              <Button
                variant="ghost"
                disabled={busy || observing === null}
                onClick={() => setPaused(observing !== false)}
              >
                {observing === false ? c.resumeCta : c.pauseCta}
              </Button>
            </div>

            {observing === false ? (
              <p className="pt-[var(--spacing-sm)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
                {c.pauseNote}
              </p>
            ) : null}

            {!health.samplesEverReceived ? (
              // Neutral nudge, verbatim from docs/03 §4 — absence of data is
              // indistinguishable from denial, and we never imply denial.
              <p className="pt-[var(--spacing-sm)] text-ink-secondary" style={{ fontSize: "var(--text-body-sm)" }}>
                {JOURNEY.healthAuth.noSamplesNudge}
              </p>
            ) : null}
          </>
        ) : (
          <>
            <p className="pb-[var(--spacing-md)] text-ink-secondary">{c.notConnected}</p>
            <Button disabled={busy} onClick={() => setSheetOpen(true)}>
              {busy ? APP.common.busy : c.connectCta}
            </Button>
          </>
        )}

        <p className="pt-[var(--spacing-md)] text-ink-tertiary" style={{ fontSize: "var(--text-body-sm)" }}>
          {c.manageHint}
        </p>
      </Screen>

      <AppleHealthSheet open={sheetOpen} appName={CORVEO_WORDMARK} onDismiss={connect} />
    </>
  );
}
