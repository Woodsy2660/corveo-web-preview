import { useEffect, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { Card } from "@/components/ui/Card";
import { CheckIcon, SyncIcon } from "@/components/ui/icons";
import { HEALTH_SYNC } from "@/copy/health-sync";
import { queryKeys } from "@/lib/api/hooks";
import { getHealthPlugin, type AuthorizationState } from "@/lib/health";
import { subscribeDemoHealth, takeCuffReading, unreadCount } from "@/lib/health/demo";
import { fmtTime } from "@/lib/format";

type Phase = "idle" | "busy" | "done";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * The Apple Health surface the patient actually sees: connected, reading
 * only, when it last looked, and a way to look now. It reports mechanism —
 * never anything about a value, and never a "denied" state we are not
 * entitled to claim.
 *
 * Sync is a real foreground check, the same one that runs unprompted on
 * every activation. In the web preview, where no cuff exists, it also stands
 * in for the cuff having taken a reading since you last looked — that part,
 * and only that part, is gated to the demo build.
 */
export function AppleHealthCard() {
  const qc = useQueryClient();
  const c = HEALTH_SYNC.card;
  const [auth, setAuth] = useState<AuthorizationState | null>(null);
  const [phase, setPhase] = useState<Phase>("idle");
  const [arrived, setArrived] = useState(false);

  useEffect(() => {
    void getHealthPlugin().getAuthorizationState().then(setAuth);
    return subscribeDemoHealth(() => {});
  }, []);

  if (auth?.state !== "requested") return null;

  const isDemoBuild = import.meta.env.DEV || import.meta.env.VITE_DEMO === "true";

  const sync = async () => {
    setPhase("busy");
    setArrived(false);

    if (isDemoBuild && unreadCount() === 0) takeCuffReading();

    // A held beat. Returning instantly reads as "nothing happened" rather
    // than "it looked and there was nothing". Kept short — the mock API's
    // own latency and the two refetches below already add most of a second.
    const [result] = await Promise.all([getHealthPlugin().syncNow(), sleep(420)]);
    setAuth(await getHealthPlugin().getAuthorizationState());

    if (result.inserted > 0) {
      await qc.invalidateQueries({ queryKey: queryKeys.readings });
      await qc.invalidateQueries({ queryKey: queryKeys.trend });
      setArrived(true);
    }

    setPhase("done");
    window.setTimeout(() => setPhase("idle"), 2200);
    if (result.inserted > 0) window.setTimeout(() => setArrived(false), 4000);
  };

  const status = arrived
    ? c.arrived
    : auth.lastSuccessfulSyncAt
      ? c.updated(fmtTime(auth.lastSuccessfulSyncAt))
      : c.waiting;

  const label = phase === "busy" ? c.sync.busy : phase === "done" ? c.sync.done : c.sync.idle;

  return (
    <Card className="mb-[var(--spacing-sm)]">
      <div className="flex items-baseline justify-between gap-[var(--spacing-sm)]">
        <span style={{ fontSize: "var(--text-body-base)", fontWeight: 500 }}>{c.title}</span>
        <span
          className="flex flex-none items-center gap-[var(--spacing-3xs)] text-ink-tertiary"
          style={{ fontSize: "var(--text-label)" }}
        >
          <span className="flex size-[13px] items-center justify-center text-accent-1">
            <CheckIcon />
          </span>
          {c.connected}
        </span>
      </div>

      <p
        className="pt-[var(--spacing-3xs)] text-ink-secondary"
        style={{ fontSize: "var(--text-body-sm)" }}
      >
        {c.readsOnly}
      </p>

      <div className="mt-[var(--spacing-xs)] flex items-center justify-between gap-[var(--spacing-sm)] border-t border-hairline pt-[var(--spacing-xs)]">
        <p
          aria-live="polite"
          className="min-w-0 truncate"
          style={{
            fontSize: "var(--text-body-sm)",
            color: arrived ? "var(--color-surface-color-1)" : "var(--app-ink-tertiary)",
            transition: "color var(--duration-base) var(--ease-brand)",
          }}
        >
          {status}
        </p>

        <button
          onClick={sync}
          disabled={phase === "busy"}
          aria-label={c.sync.aria}
          className="inline-flex flex-none items-center gap-[var(--spacing-2xs)] rounded-round border border-hairline px-[var(--spacing-sm)] py-[var(--spacing-2xs)] active:opacity-70 disabled:opacity-70"
          style={{
            fontSize: "var(--text-body-sm)",
            lineHeight: "var(--leading-label)",
            fontWeight: 500,
            color: phase === "done" ? "var(--color-surface-color-1)" : "var(--app-heading)",
            borderColor: phase === "done" ? "var(--color-surface-color-1)" : undefined,
            transitionProperty: "color, border-color, opacity",
            transitionDuration: "var(--duration-base)",
            transitionTimingFunction: "var(--ease-brand)",
          }}
        >
          <span
            className={`flex size-[15px] items-center justify-center ${phase === "busy" ? "spin" : ""}`}
          >
            {phase === "done" ? <CheckIcon /> : <SyncIcon />}
          </span>
          {label}
        </button>
      </div>
    </Card>
  );
}
